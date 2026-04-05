extends Node

const RECIPES_PATH := "res://data/lab_recipes/"
const UNLOCKS_PATH := "user://lab_unlocks.json"

signal recipe_completed(recipe: Resource)

var all_recipes: Array[Resource] = []
var active_recipe_id := ""
var recipe_progress: Dictionary = {}  # recipe_id -> float (0.0 a 1.0)
var active_timer: Timer = null
var pending_output: Array[Dictionary] = []

# action_types desbloqueados globalmente: ["upgrade", "loop", ...]
var unlocked_columns: Array = []

func _ready() -> void:
	_load_unlocks()
	_load_recipes()

# ── Carga ─────────────────────────────────────────────────────────────────────

func _load_recipes() -> void:
	var dir := DirAccess.open(RECIPES_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var recipe := load(RECIPES_PATH + file) as Resource
			if recipe:
				all_recipes.append(recipe)
				_unlock_column(recipe.location, recipe.action_type)
		file = dir.get_next()

func get_recipe_by_id(id: String) -> Resource:
	for r in all_recipes:
		if r.id == id:
			return r
	return null

# ── Activar / pausar ──────────────────────────────────────────────────────────

func activate_recipe(recipe: Resource) -> void:
	if recipe.id == active_recipe_id:
		return
	_pause_current()
	_start_recipe(recipe)

func _pause_current() -> void:
	if active_recipe_id == "" or active_timer == null:
		return
	var recipe := get_recipe_by_id(active_recipe_id)
	if recipe == null:
		return
	var elapsed_this_session := active_timer.wait_time - active_timer.time_left
	var previous: float = recipe_progress.get(active_recipe_id, 0.0)
	recipe_progress[active_recipe_id] = clampf(previous + elapsed_this_session / recipe.craft_time, 0.0, 1.0)
	active_timer.stop()
	active_recipe_id = ""

func _start_recipe(recipe: Resource) -> void:
	active_recipe_id = recipe.id
	var saved: float = recipe_progress.get(recipe.id, 0.0)
	var remaining: float = recipe.craft_time * (1.0 - saved)

	if active_timer:
		active_timer.queue_free()

	active_timer = Timer.new()
	active_timer.wait_time = maxf(remaining, 0.05)
	active_timer.one_shot = true
	active_timer.autostart = true
	active_timer.timeout.connect(func(): _on_recipe_complete(recipe))
	add_child(active_timer)

func _on_recipe_complete(recipe: Resource) -> void:
	pending_output.append({"name": recipe.recipe_name, "reward": recipe.reward})
	recipe_progress.erase(recipe.id)
	recipe_completed.emit(recipe)
	_start_recipe(recipe)

# ── Output ────────────────────────────────────────────────────────────────────

func get_current_progress(recipe_id: String) -> float:
	if recipe_id == active_recipe_id and active_timer != null and not active_timer.is_stopped():
		var recipe := get_recipe_by_id(recipe_id)
		if recipe == null:
			return 0.0
		var base: float = recipe_progress.get(recipe_id, 0.0)
		var elapsed := active_timer.wait_time - active_timer.time_left
		return clampf(base + elapsed / recipe.craft_time, 0.0, 1.0)
	return recipe_progress.get(recipe_id, 0.0)

func take_all_output() -> Array[Dictionary]:
	var result := pending_output.duplicate()
	pending_output.clear()
	return result

# ── Columnas desbloqueadas ────────────────────────────────────────────────────

func is_column_unlocked(_location: String, action_type: String) -> bool:
	return unlocked_columns.has(action_type)

func _unlock_column(_location: String, action_type: String) -> void:
	if not unlocked_columns.has(action_type):
		unlocked_columns.append(action_type)
		_save_unlocks()

func _save_unlocks() -> void:
	var file := FileAccess.open(UNLOCKS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(unlocked_columns))

func _load_unlocks() -> void:
	if not FileAccess.file_exists(UNLOCKS_PATH):
		return
	var file := FileAccess.open(UNLOCKS_PATH, FileAccess.READ)
	if file:
		var result = JSON.parse_string(file.get_as_text())
		if result is Array:
			unlocked_columns = result
