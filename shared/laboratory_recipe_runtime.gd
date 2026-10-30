class_name LaboratoryRecipeRuntime
extends RefCounted

const LabRecipeActionScript := preload("res://data/lab_recipe_action.gd")

## Ciclo temporal de una receta activa. El estado conserva los datos públicos;
## este servicio concentra Timer, pausa, progreso y reanudación.

var _state

func _init(state) -> void:
	_state = state

func pause() -> void:
	if _state.active_recipe_id == "" or _state.active_timer == null:
		return
	var recipe: Resource = _state.get_recipe_by_id(_state.active_recipe_id)
	if recipe == null:
		return
	var elapsed: float = _state.active_timer.wait_time - _state.active_timer.time_left
	var previous: float = _state.recipe_progress.get(_state.active_recipe_id, 0.0)
	_state.recipe_progress[_state.active_recipe_id] = clampf(previous + elapsed / recipe.craft_time, 0.0, 1.0)
	_state.active_timer.stop()
	_state.active_recipe_id = ""

func start(recipe: Resource) -> void:
	_state.active_recipe_id = recipe.id
	var saved: float = _state.recipe_progress.get(recipe.id, 0.0)
	var remaining: float = recipe.craft_time * (1.0 - saved)
	if _state.active_timer:
		_state.active_timer.queue_free()
	_state.active_timer = Timer.new()
	_state.active_timer.wait_time = maxf(remaining, 0.05)
	_state.active_timer.one_shot = true
	_state.active_timer.autostart = true
	_state.active_timer.timeout.connect(func(): complete(recipe))
	_state.add_child(_state.active_timer)

func complete(recipe: Resource) -> void:
	_state.grant_reward(recipe.reward, recipe.recipe_name)
	for reward in recipe.extra_rewards:
		_state.grant_reward(reward, recipe.recipe_name)
	_state.recipe_progress.erase(recipe.id)
	if recipe.action_type != LabRecipeActionScript.UPGRADE:
		if _state.has_ingredients(recipe):
			_state.consume_ingredients(recipe)
			start(recipe)
		else:
			_state.active_recipe_id = ""
	else:
		_state.active_recipe_id = ""
		_state.complete_recipe(recipe.id)
	_state.recipe_completed.emit(recipe)

func progress(recipe_id: String) -> float:
	if recipe_id == _state.active_recipe_id and _state.active_timer != null and not _state.active_timer.is_stopped():
		var recipe: Resource = _state.get_recipe_by_id(recipe_id)
		if recipe == null:
			return 0.0
		var base: float = _state.recipe_progress.get(recipe_id, 0.0)
		var elapsed: float = _state.active_timer.wait_time - _state.active_timer.time_left
		return clampf(base + elapsed / recipe.craft_time, 0.0, 1.0)
	return _state.recipe_progress.get(recipe_id, 0.0)
