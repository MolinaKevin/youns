extends Node

const RECIPES_PATH := "res://data/lab_recipes/"

signal recipe_completed(recipe: Resource)
signal recipe_unlocked(recipe: Resource)
signal recipes_loaded
signal pending_output_changed

var all_recipes: Array[Resource] = []
var active_recipe_id := ""
var recipe_progress: Dictionary = {}  
var active_timer: Timer = null
var pending_output: Dictionary = {}  
var recipes_by_ingredient: Dictionary = {} 

var unlocked_columns: Array = []
var _loading := true

func _ready() -> void:
	call_deferred("_load_recipes")

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
				if GameState.player_save.unlocked_recipe_ids.has(recipe.id):
					_unlock_column(recipe.location, recipe.action_type)
				if recipe.starts_unlocked and not GameState.player_save.unlocked_recipe_ids.has(recipe.id):
					unlock_recipe(recipe.id)
				for ing in recipe.ingredients:
					if not recipes_by_ingredient.has(ing["id"]):
						recipes_by_ingredient[ing["id"]] = []
					recipes_by_ingredient[ing["id"]].append(recipe)
		file = dir.get_next()
	_loading = false
	recipes_loaded.emit()

func get_recipe_by_id(id: String) -> Resource:
	for r in all_recipes:
		if r.id == id:
			return r
	return null

# ── Activar / pausar ──────────────────────────────────────────────────────────

func activate_recipe(recipe: Resource) -> void:
	if recipe.action_type == "instant":
		if not has_ingredients(recipe):
			return
		_pause_current()
		_consume_ingredients(recipe)
		_process_reward(recipe.reward, recipe.recipe_name)
		for r in recipe.extra_rewards:
			_process_reward(r, recipe.recipe_name)
		recipe_completed.emit(recipe)
		return
	if recipe.id == active_recipe_id:
		return
	var is_resuming: bool = recipe_progress.get(recipe.id, 0.0) > 0.0
	if not is_resuming:
		if not has_ingredients(recipe):
			return
		_consume_ingredients(recipe)
	_pause_current()
	_start_recipe(recipe)

func has_ingredients(recipe: Resource) -> bool:
	if GameState.player_save != null and GameState.player_save.gold < recipe.gold_cost:
		return false
	for ing in recipe.ingredients:
		if pending_output.get(ing["id"], {}).get("count", 0) < ing["amount"]:
			return false
	return true

func _consume_ingredients(recipe: Resource) -> void:
	if recipe.gold_cost > 0 and GameState.player_save != null:
		GameState.player_save.gold = max(0, GameState.player_save.gold - recipe.gold_cost)
		GameState.save_player_save()
	for ing in recipe.ingredients:
		var item_id: String = ing["id"]
		var new_count: int = pending_output[item_id]["count"] - ing["amount"]
		if new_count <= 0:
			pending_output.erase(item_id)
		else:
			pending_output[item_id]["count"] = new_count
	pending_output_changed.emit()

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
	_process_reward(recipe.reward, recipe.recipe_name)
	for r in recipe.extra_rewards:
		_process_reward(r, recipe.recipe_name)
	recipe_progress.erase(recipe.id)
	if recipe.action_type != "upgrade":
		if has_ingredients(recipe):
			_consume_ingredients(recipe)
			_start_recipe(recipe)
		else:
			active_recipe_id = ""
	else:
		active_recipe_id = ""
		_complete_recipe(recipe.id)
	recipe_completed.emit(recipe)

func _process_reward(reward: Dictionary, _recipe_name: String) -> void:
	match reward.get("type", ""):
		"unlock_recipe":
			unlock_recipe(reward["id"])
		"unlock_clock_ui":
			GameState.player_save.clock_ui_unlocked = true
			GameState.save_player_save()
			GameState.sync_overworld_ui_visibility()
		"unlock_care_ui":
			GameState.player_save.care_ui_unlocked = true
			GameState.save_player_save()
			GameState.sync_overworld_ui_visibility()
		"item":
			var item_id: String = reward["id"]
			var current_count: int = pending_output.get(item_id, {}).get("count", 0)
			if current_count < 99:
				var amount: int = reward.get("amount", 1)
				var item_recipe := get_recipe_by_id(item_id)
				var item_name: String = item_id
				if item_recipe:
					item_name = item_recipe.item_name if item_recipe.item_name != "" else item_recipe.recipe_name
				pending_output[item_id] = {"name": item_name, "count": mini(current_count + amount, 99)}
				pending_output_changed.emit()
			_check_indirect_unlocks(item_id)

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

func take_all_output() -> Dictionary:
	var result := pending_output.duplicate()
	pending_output.clear()
	pending_output_changed.emit()
	return result

# ── Columnas desbloqueadas ────────────────────────────────────────────────────

func is_column_unlocked(_location: String, action_type: String) -> bool:
	return unlocked_columns.has(action_type)

func _unlock_column(_location: String, action_type: String) -> void:
	if not unlocked_columns.has(action_type):
		unlocked_columns.append(action_type)

# ── Desbloqueo de recetas ─────────────────────────────────────────────────────

func unlock_recipe(recipe_id: String) -> void:
	if GameState.player_save.unlocked_recipe_ids.has(recipe_id):
		return
	GameState.player_save.unlocked_recipe_ids.append(recipe_id)
	GameState.save_player_save()
	var recipe := get_recipe_by_id(recipe_id)
	if recipe:
		_unlock_column(recipe.location, recipe.action_type)
		if not _loading:
			recipe_unlocked.emit(recipe)

func is_recipe_unlocked(recipe_id: String) -> bool:
	return GameState.player_save.unlocked_recipe_ids.has(recipe_id)

# ── Completado de upgrades ────────────────────────────────────────────────────

func is_recipe_completed(recipe_id: String) -> bool:
	return GameState.player_save.completed_recipe_ids.has(recipe_id)

func _complete_recipe(recipe_id: String) -> void:
	if GameState.player_save.completed_recipe_ids.has(recipe_id):
		return
	GameState.player_save.completed_recipe_ids.append(recipe_id)
	GameState.save_player_save()

# ── Desbloqueo indirecto ──────────────────────────────────────────────────────

func _check_indirect_unlocks(produced_item_id: String) -> void:
	var candidates: Array = recipes_by_ingredient.get(produced_item_id, [])
	for recipe in candidates:
		if recipe.needs_research or is_recipe_unlocked(recipe.id) or is_recipe_completed(recipe.id):
			continue
		var satisfied := true
		for ing in recipe.ingredients:
			if pending_output.get(ing["id"], {}).get("count", 0) < ing["amount"]:
				satisfied = false
				break
		if satisfied:
			unlock_recipe(recipe.id)
