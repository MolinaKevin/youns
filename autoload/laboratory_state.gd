extends Node

const LabRewardScript := preload("res://data/lab_reward.gd")
const LabRecipeActionScript := preload("res://data/lab_recipe_action.gd")
const GameDataValidatorScript := preload("res://shared/game_data_validator.gd")
const RecipeCatalog := preload("res://shared/laboratory_recipe_catalog.gd")
const RewardService := preload("res://shared/laboratory_reward_service.gd")
const RecipeRuntime := preload("res://shared/laboratory_recipe_runtime.gd")
const RECIPES_PATH := "res://data/lab_recipes/"

signal recipe_completed(recipe: Resource)
signal recipe_unlocked(recipe: Resource)
signal pending_output_changed

var all_recipes: Array[Resource] = []
var active_recipe_id := ""
var recipe_progress: Dictionary = {}  
var active_timer: Timer = null
var pending_output: Dictionary = {}  
var recipes_by_ingredient: Dictionary = {} 

var unlocked_columns: Array = []
var _loading := true
var _echoes: LaboratoryEchoes
var _rewards: RewardService
var _runtime: RecipeRuntime

var is_loaded: bool:
	get:
		return not _loading

func _ready() -> void:
	_echoes = LaboratoryEchoes.new(self)
	_rewards = RewardService.new(self)
	_runtime = RecipeRuntime.new(self)
	call_deferred("_load_recipes_when_ready")

func _load_recipes_when_ready() -> void:
	while GameState.save_service.player_save == null:
		await get_tree().process_frame
	_load_recipes()

## Espera a que el catálogo esté disponible para consumidores de UI o mundo.
## La inicialización sigue siendo responsabilidad del autoload; los
## consumidores no necesitan suscribirse a una señal técnica.
func ensure_loaded() -> void:
	while _loading:
		await get_tree().process_frame

# ── Carga ─────────────────────────────────────────────────────────────────────

func _load_recipes() -> void:
	all_recipes = RecipeCatalog.load_all(RECIPES_PATH)
	recipes_by_ingredient = RecipeCatalog.index_by_ingredient(all_recipes)
	unlocked_columns.clear()
	for recipe in all_recipes:
		if GameState.save_service.player_save.unlocked_recipe_ids.has(recipe.id):
			_unlock_column(recipe.location, recipe.action_type)
		if recipe.starts_unlocked and not GameState.save_service.player_save.unlocked_recipe_ids.has(recipe.id):
			unlock_recipe(recipe.id)
	for error_text in GameDataValidatorScript.recipe_errors(all_recipes):
		push_error("LaboratoryState: " + error_text)
	_loading = false

# ── Guardado ─────────────────────────────────────────────────────────────────

## Copia lo producido, el avance de las recetas y cuál estaba corriendo.
func write_to_save(save: PlayerSaveData) -> void:
	save.lab_pending_output = pending_output.duplicate(true)
	var progress := recipe_progress.duplicate()
	if active_recipe_id != "":
		progress[active_recipe_id] = get_current_progress(active_recipe_id)
	save.lab_recipe_progress = progress
	save.lab_active_recipe_id = active_recipe_id

## Deja el laboratorio como el de la partida (nueva o cargada).
func restore_from_save(save: PlayerSaveData) -> void:
	if active_timer:
		active_timer.queue_free()
		active_timer = null
	active_recipe_id = ""
	pending_output = save.lab_pending_output.duplicate(true)
	recipe_progress = save.lab_recipe_progress.duplicate()
	_loading = true
	_load_recipes()
	# La investigación que estaba corriendo sigue desde su avance.
	var active := get_recipe_by_id(save.lab_active_recipe_id)
	if active != null:
		_start_recipe(active)
	pending_output_changed.emit()

func get_recipe_by_id(id: String) -> Resource:
	for r in all_recipes:
		if r.id == id:
			return r
	return null

# ── Activar / pausar ──────────────────────────────────────────────────────────

func activate_recipe(recipe: Resource) -> void:
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
	if recipe.id == active_recipe_id:
		return
	var is_resuming: bool = recipe_progress.get(recipe.id, 0.0) > 0.0
	if not is_resuming:
		if not has_ingredients(recipe):
			return
		consume_ingredients(recipe)
	_pause_current()
	_start_recipe(recipe)

func has_ingredients(recipe: Resource) -> bool:
	if GameState.save_service.player_save != null and GameState.save_service.player_save.gold < recipe.gold_cost:
		return false
	return _has_enough_ingredients(recipe.ingredients)

func _has_enough_ingredients(ingredients: Array) -> bool:
	for ing in ingredients:
		if pending_output.get(ing["id"], {}).get("count", 0) < _ingredient_amount(ing):
			return false
	return true

func consume_ingredients(recipe: Resource) -> void:
	if recipe.gold_cost > 0 and GameState.save_service.player_save != null:
		GameState.save_service.player_save.gold = max(0, GameState.save_service.player_save.gold - recipe.gold_cost)
	for ing in recipe.ingredients:
		var item_id: String = ing["id"]
		var new_count: int = pending_output[item_id]["count"] - _ingredient_amount(ing)
		if new_count <= 0:
			pending_output.erase(item_id)
		else:
			pending_output[item_id]["count"] = new_count
	pending_output_changed.emit()

func _ingredient_amount(ingredient: Dictionary) -> int:
	var amount := int(ingredient.get("amount", 0))
	if str(ingredient.get("id", "")) == "datos" and GameState.save_service.player_save != null:
		amount = ceili(float(amount) * (1.0 - GameState.save_service.player_save.lab_data_cost_reduction))
	return maxi(1, amount)

## Pausa la receta activa y guarda su avance en memoria. La UI y los cambios
## de partida pueden usarlo sin depender del temporizador interno.
func pause_active_recipe() -> void:
	_ensure_runtime()
	_runtime.pause()


func _pause_current() -> void:
	_ensure_runtime()
	_runtime.pause()

func _start_recipe(recipe: Resource) -> void:
	_ensure_runtime()
	_runtime.start(recipe)

func _on_recipe_complete(recipe: Resource) -> void:
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
	var current_count: int = pending_output.get(item_id, {}).get("count", 0)
	if current_count >= limit or amount <= 0:
		return
	pending_output[item_id] = {
		"id": item_id,
		"name": item_name,
		"count": mini(current_count + amount, limit),
	}
	pending_output_changed.emit()

# ── Output ────────────────────────────────────────────────────────────────────

func get_current_progress(recipe_id: String) -> float:
	_ensure_runtime()
	return _runtime.progress(recipe_id)

func _ensure_runtime() -> void:
	if _runtime == null:
		_runtime = RecipeRuntime.new(self)

func take_all_output() -> Dictionary:
	var result := pending_output.duplicate()
	pending_output.clear()
	pending_output_changed.emit()
	return result

## Devuelve al depósito lo que no pudo entrar al inventario del jugador.
func restore_output(entries: Dictionary) -> void:
	pending_output = entries.duplicate(true)
	pending_output_changed.emit()

# ── Columnas desbloqueadas ────────────────────────────────────────────────────

func is_column_unlocked(_location: String, action_type: String) -> bool:
	return unlocked_columns.has(action_type)

func _unlock_column(_location: String, action_type: String) -> void:
	if not unlocked_columns.has(action_type):
		unlocked_columns.append(action_type)

# ── Desbloqueo de recetas ─────────────────────────────────────────────────────

func unlock_recipe(recipe_id: String) -> void:
	if GameState.save_service.player_save.unlocked_recipe_ids.has(recipe_id):
		return
	GameState.save_service.player_save.unlocked_recipe_ids.append(recipe_id)
	var recipe := get_recipe_by_id(recipe_id)
	if recipe:
		_unlock_column(recipe.location, recipe.action_type)
		if not _loading:
			recipe_unlocked.emit(recipe)

func is_recipe_unlocked(recipe_id: String) -> bool:
	return GameState.save_service.player_save.unlocked_recipe_ids.has(recipe_id)

# ── Completado de upgrades ────────────────────────────────────────────────────

func is_recipe_completed(recipe_id: String) -> bool:
	return GameState.save_service.player_save.completed_recipe_ids.has(recipe_id)

func complete_recipe(recipe_id: String) -> void:
	if GameState.save_service.player_save.completed_recipe_ids.has(recipe_id):
		return
	GameState.save_service.player_save.completed_recipe_ids.append(recipe_id)

# ── Desbloqueo indirecto ──────────────────────────────────────────────────────

func check_indirect_unlocks(produced_item_id: String) -> void:
	var candidates: Array = recipes_by_ingredient.get(produced_item_id, [])
	for recipe in candidates:
		if recipe.needs_research or is_recipe_unlocked(recipe.id) or is_recipe_completed(recipe.id):
			continue
		if _has_enough_ingredients(recipe.ingredients):
			unlock_recipe(recipe.id)
