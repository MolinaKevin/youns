extends Node

const LabRewardScript := preload("res://data/lab_reward.gd")
const LabRecipeActionScript := preload("res://data/lab_recipe_action.gd")
const GameDataValidatorScript := preload("res://shared/game_data_validator.gd")
const RecipeCatalog := preload("res://shared/laboratory_recipe_catalog.gd")
const RewardService := preload("res://shared/laboratory_reward_service.gd")
const RecipeRuntime := preload("res://shared/laboratory_recipe_runtime.gd")
const RECIPES_PATH := "res://data/lab_recipes/"

signal recipe_completed(recipe: LabRecipe)
signal recipe_unlocked(recipe: LabRecipe)
signal pending_output_changed
signal recipes_loaded

## Privado: nadie fuera de este autoload debe leer ni mutar estas colecciones
## directamente. Usar los métodos de abajo (recipes(), output_*, *_paused_progress,
## is_column_unlocked, etc.) o, en tests, la sección "Soporte de tests" al final.
var _all_recipes: Array[LabRecipe] = []
var _active_recipe_id := ""
var _recipe_progress: Dictionary = {}
var _active_timer: Timer = null
var _pending_output: Dictionary = {}
var _recipes_by_ingredient: Dictionary = {}
var _unlocked_columns: Array = []

var _loading := true
var _echoes: LaboratoryEchoes
var _rewards: RewardService
var _runtime: RecipeRuntime
var _progress: LaboratoryProgress

var is_loaded: bool:
	get:
		return not _loading

func _ready() -> void:
	_echoes = LaboratoryEchoes.new(self)
	_rewards = RewardService.new(self, GlobalHUD.sync_overworld_ui_visibility)
	_runtime = RecipeRuntime.new(self)
	_progress = LaboratoryProgress.new(PlayerSessionAccess.save)
	if PlayerSessionAccess.has_active_save():
		_load_recipes()
	else:
		GameState.save_ready.connect(_on_player_save_ready)


func _on_player_save_ready(_save: PlayerSaveData) -> void:
	if _loading:
		_load_recipes()

## Espera a que el catálogo esté disponible para consumidores de UI o mundo.
## La inicialización sigue siendo responsabilidad del autoload; los
## consumidores no necesitan suscribirse a una señal técnica.
func ensure_loaded() -> void:
	if _loading:
		await recipes_loaded

# ── Carga ─────────────────────────────────────────────────────────────────────

func _load_recipes() -> void:
	_all_recipes = RecipeCatalog.load_all(RECIPES_PATH)
	_recipes_by_ingredient = RecipeCatalog.index_by_ingredient(_all_recipes)
	_unlocked_columns.clear()
	for recipe in _all_recipes:
		if _progress.is_unlocked(recipe.id):
			_unlock_column(recipe.location, recipe.action_type)
		if recipe.starts_unlocked and not _progress.is_unlocked(recipe.id):
			unlock_recipe(recipe.id)
	for error_text in GameDataValidatorScript.recipe_errors(_all_recipes):
		push_error("LaboratoryState: " + error_text)
	_loading = false
	recipes_loaded.emit()

## Copia de solo lectura del catálogo. Para consultas puntuales por id usar
## get_recipe_by_id(); esto es para listar/filtrar (ej. UI del árbol tecnológico).
func recipes() -> Array[LabRecipe]:
	return _all_recipes.duplicate()

# ── Guardado ─────────────────────────────────────────────────────────────────

## Copia lo producido, el avance de las recetas y cuál estaba corriendo.
func write_to_save(save: PlayerSaveData) -> void:
	save.lab_pending_output = _pending_output.duplicate(true)
	var progress_snapshot := _recipe_progress.duplicate()
	if _active_recipe_id != "":
		progress_snapshot[_active_recipe_id] = get_current_progress(_active_recipe_id)
	save.lab_recipe_progress = progress_snapshot
	save.lab_active_recipe_id = _active_recipe_id


## API de runtime. El ciclo de recetas no toca estos campos directo, solo a
## través de estos métodos.
func active_recipe() -> String:
	return _active_recipe_id


func set_active_recipe(recipe_id: String) -> void:
	_active_recipe_id = recipe_id


func runtime_timer() -> Timer:
	return _active_timer


func replace_runtime_timer(timer: Timer) -> void:
	if _active_timer != null and _active_timer != timer:
		_active_timer.stop()
		_active_timer.queue_free()
	_active_timer = timer

## Deja el laboratorio como el de la partida (nueva o cargada).
func restore_from_save(save: PlayerSaveData) -> void:
	replace_runtime_timer(null)
	set_active_recipe("")
	_pending_output = save.lab_pending_output.duplicate(true)
	_recipe_progress = save.lab_recipe_progress.duplicate()
	_loading = true
	_load_recipes()
	# La investigación que estaba corriendo sigue desde su avance.
	var active := get_recipe_by_id(save.lab_active_recipe_id)
	if active != null:
		_start_recipe(active)
	pending_output_changed.emit()

func get_recipe_by_id(id: String) -> LabRecipe:
	for r in _all_recipes:
		if r.id == id:
			return r
	return null

# ── Activar / pausar ──────────────────────────────────────────────────────────

func activate_recipe(recipe: LabRecipe) -> void:
	if recipe.action_type == LabRecipeActionScript.UPGRADE and is_recipe_completed(recipe.id):
		return
	if recipe.action_type == LabRecipeActionScript.INSTANT:
		if not has_ingredients(recipe):
			return
		_pause_current()
		consume_ingredients(recipe)
		grant_reward(recipe.reward, recipe.recipe_name)
		for r in recipe.extra_rewards:
			grant_reward(r, recipe.recipe_name)
		recipe_completed.emit(recipe)
		return
	if recipe.id == _active_recipe_id:
		return
	var is_resuming: bool = _recipe_progress.get(recipe.id, 0.0) > 0.0
	if not is_resuming:
		if not has_ingredients(recipe):
			return
		consume_ingredients(recipe)
	_pause_current()
	_start_recipe(recipe)

func has_ingredients(recipe: LabRecipe) -> bool:
	if not _progress.has_gold(recipe.gold_cost):
		return false
	return _has_enough_ingredients(recipe.ingredients)

func _has_enough_ingredients(ingredients: Array) -> bool:
	for ing in ingredients:
		if output_count(str(ing["id"])) < _ingredient_amount(ing):
			return false
	return true

func consume_ingredients(recipe: LabRecipe) -> void:
	_progress.spend_gold(recipe.gold_cost)
	for ing in recipe.ingredients:
		var item_id: String = ing["id"]
		var new_count := output_count(item_id) - _ingredient_amount(ing)
		if new_count <= 0:
			_pending_output.erase(item_id)
		else:
			var entry: Dictionary = _pending_output[item_id]
			entry[LaboratoryOutputEntry.COUNT] = new_count
	pending_output_changed.emit()

func _ingredient_amount(ingredient: Dictionary) -> int:
	var amount := int(ingredient.get("amount", 0))
	var save := progress().save()
	if str(ingredient.get("id", "")) == "datos" and save != null:
		amount = ceili(float(amount) * (1.0 - save.lab_data_cost_reduction))
	return maxi(1, amount)

## Pausa la receta activa y guarda su avance en memoria. La UI y los cambios
## de partida pueden usarlo sin depender del temporizador interno.
func pause_active_recipe() -> void:
	_ensure_runtime()
	_runtime.pause()


func _pause_current() -> void:
	_ensure_runtime()
	_runtime.pause()

func _start_recipe(recipe: LabRecipe) -> void:
	_ensure_runtime()
	_runtime.start(recipe)

func _on_recipe_complete(recipe: LabRecipe) -> void:
	_ensure_runtime()
	_runtime.complete(recipe)

func grant_reward(reward: Dictionary, _recipe_name: String) -> void:
	if _rewards == null:
		_rewards = RewardService.new(self)
	_rewards.grant(reward)


## Acredita al depósito los Ecos juntados en un combate (ver CombatState.echoes_earned).
func deposit_echoes(counts: Dictionary) -> void:
	_echoes.deposit(counts)


func add_output_item(item_id: String, item_name: String, amount: int, limit: int) -> void:
	var current_count := output_count(item_id)
	if current_count >= limit or amount <= 0:
		return
	_pending_output[item_id] = LaboratoryOutputEntry.make(item_id, item_name, mini(current_count + amount, limit),
		output_data_path(item_id))
	pending_output_changed.emit()

# ── Output ────────────────────────────────────────────────────────────────────

func get_current_progress(recipe_id: String) -> float:
	_ensure_runtime()
	return _runtime.progress(recipe_id)

func has_paused_progress(recipe_id: String) -> bool:
	return _recipe_progress.has(recipe_id)

func paused_progress(recipe_id: String) -> float:
	return float(_recipe_progress.get(recipe_id, 0.0))


func set_paused_progress(recipe_id: String, value: float) -> void:
	_recipe_progress[recipe_id] = clampf(value, 0.0, 1.0)


func clear_paused_progress(recipe_id: String) -> void:
	_recipe_progress.erase(recipe_id)


func clear_all_paused_progress() -> void:
	_recipe_progress.clear()

func _ensure_runtime() -> void:
	if _runtime == null:
		_runtime = RecipeRuntime.new(self)

func progress() -> LaboratoryProgress:
	if _progress == null:
		_progress = LaboratoryProgress.new(PlayerSessionAccess.save)
	return _progress

func take_all_output() -> Dictionary:
	var result := _pending_output.duplicate()
	_pending_output.clear()
	pending_output_changed.emit()
	return result

func output_entries() -> Dictionary:
	return _pending_output.duplicate(true)

func output_entry(item_id: String) -> Dictionary:
	return _pending_output.get(item_id, {}).duplicate(true)

func output_count(item_id: String) -> int:
	return LaboratoryOutputEntry.count_of(_pending_output.get(item_id, {}))

func output_data_path(item_id: String) -> String:
	return LaboratoryOutputEntry.data_path_of(_pending_output.get(item_id, {}))

func set_output_data_path(item_id: String, path: String) -> void:
	if not _pending_output.has(item_id):
		return
	_pending_output[item_id][LaboratoryOutputEntry.DATA_PATH] = path

## Devuelve al depósito lo que no pudo entrar al inventario del jugador.
func restore_output(entries: Dictionary) -> void:
	_pending_output = entries.duplicate(true)
	pending_output_changed.emit()

# ── Columnas desbloqueadas ────────────────────────────────────────────────────

func is_column_unlocked(_location: String, action_type: String) -> bool:
	return _unlocked_columns.has(action_type)

func _unlock_column(_location: String, action_type: String) -> void:
	if not _unlocked_columns.has(action_type):
		_unlocked_columns.append(action_type)

# ── Desbloqueo de recetas ─────────────────────────────────────────────────────

func unlock_recipe(recipe_id: String) -> void:
	if not _progress.unlock(recipe_id):
		return
	var recipe := get_recipe_by_id(recipe_id)
	if recipe:
		_unlock_column(recipe.location, recipe.action_type)
		if not _loading:
			recipe_unlocked.emit(recipe)

func is_recipe_unlocked(recipe_id: String) -> bool:
	return _progress.is_unlocked(recipe_id)

# ── Completado de upgrades ────────────────────────────────────────────────────

func is_recipe_completed(recipe_id: String) -> bool:
	return _progress.is_completed(recipe_id)

func complete_recipe(recipe_id: String) -> void:
	_progress.complete(recipe_id)

# ── Desbloqueo indirecto ──────────────────────────────────────────────────────

func check_indirect_unlocks(produced_item_id: String) -> void:
	var candidates: Array = _recipes_by_ingredient.get(produced_item_id, [])
	for recipe in candidates:
		if recipe.needs_research or is_recipe_unlocked(recipe.id) or is_recipe_completed(recipe.id):
			continue
		if _has_enough_ingredients(recipe.ingredients):
			unlock_recipe(recipe.id)

# ── Soporte de tests ──────────────────────────────────────────────────────────
# Única puerta explícita para que los tests reemplacen el estado interno sin
# tocar las colecciones privadas directamente.

## Reemplaza el catálogo completo por uno controlado por el test y reconstruye
## el índice por ingrediente (antes había que mantenerlo a mano en cada test).
func set_recipes_for_test(recipes_list: Array[LabRecipe]) -> void:
	_all_recipes = recipes_list
	_recipes_by_ingredient = RecipeCatalog.index_by_ingredient(_all_recipes)

func add_recipe_for_test(recipe: LabRecipe) -> void:
	_all_recipes.append(recipe)
	_recipes_by_ingredient = RecipeCatalog.index_by_ingredient(_all_recipes)

func set_pending_output_for_test(item_id: String, count: int) -> void:
	_pending_output[item_id] = LaboratoryOutputEntry.make(item_id, item_id, count)

## antes_de/despues_de un test: guardar y restaurar el estado real para no
## pisar la partida cargada por GameState entre tests.
func snapshot_for_test() -> Dictionary:
	return {
		"pending_output": _pending_output.duplicate(true),
		"unlocked_columns": _unlocked_columns.duplicate(true),
		"all_recipes": _all_recipes.duplicate(),
		"recipes_by_ingredient": _recipes_by_ingredient.duplicate(true),
		"active_recipe_id": _active_recipe_id,
		"recipe_progress": _recipe_progress.duplicate(true),
	}

func restore_snapshot_for_test(snapshot: Dictionary) -> void:
	_pending_output = snapshot["pending_output"]
	_unlocked_columns = snapshot["unlocked_columns"]
	_all_recipes = snapshot["all_recipes"]
	_recipes_by_ingredient = snapshot["recipes_by_ingredient"]
	_active_recipe_id = snapshot["active_recipe_id"]
	_recipe_progress = snapshot["recipe_progress"]

func clear_for_test() -> void:
	_pending_output = {}
	_unlocked_columns = []
	_all_recipes = []
	_recipes_by_ingredient = {}
	_active_recipe_id = ""
	_recipe_progress = {}
