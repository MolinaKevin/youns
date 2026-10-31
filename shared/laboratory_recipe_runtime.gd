class_name LaboratoryRecipeRuntime
extends RefCounted

const LabRecipeActionScript := preload("res://data/lab_recipe_action.gd")

## Ciclo temporal de una receta activa. El estado conserva los datos públicos;
## este servicio concentra Timer, pausa, progreso y reanudación.

var _state

func _init(state) -> void:
	_state = state

func pause() -> void:
	var active_recipe_id: String = _state.active_recipe()
	var timer: Timer = _state.runtime_timer()
	if active_recipe_id == "" or timer == null:
		return
	var recipe: LabRecipe = _state.get_recipe_by_id(active_recipe_id)
	if recipe == null:
		return
	var elapsed: float = timer.wait_time - timer.time_left
	var previous: float = _state.paused_progress(active_recipe_id)
	_state.set_paused_progress(active_recipe_id, previous + elapsed / recipe.craft_time)
	timer.stop()
	_state.set_active_recipe("")

func start(recipe: LabRecipe) -> void:
	_state.set_active_recipe(recipe.id)
	var saved: float = _state.paused_progress(recipe.id)
	var remaining: float = recipe.craft_time * (1.0 - saved)
	var timer := Timer.new()
	timer.wait_time = maxf(remaining, 0.05)
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func(): complete(recipe))
	_state.replace_runtime_timer(timer)
	_state.add_child(timer)

func complete(recipe: LabRecipe) -> void:
	_state.grant_reward(recipe.reward, recipe.recipe_name)
	for reward in recipe.extra_rewards:
		_state.grant_reward(reward, recipe.recipe_name)
	_state.clear_paused_progress(recipe.id)
	if recipe.action_type != LabRecipeActionScript.UPGRADE:
		if _state.has_ingredients(recipe):
			_state.consume_ingredients(recipe)
			start(recipe)
		else:
			_state.set_active_recipe("")
	else:
		_state.set_active_recipe("")
		_state.complete_recipe(recipe.id)
	_state.recipe_completed.emit(recipe)

func progress(recipe_id: String) -> float:
	var timer: Timer = _state.runtime_timer()
	if recipe_id == _state.active_recipe() and timer != null and not timer.is_stopped():
		var recipe: LabRecipe = _state.get_recipe_by_id(recipe_id)
		if recipe == null:
			return 0.0
		var base: float = _state.paused_progress(recipe_id)
		var elapsed: float = timer.wait_time - timer.time_left
		return clampf(base + elapsed / recipe.craft_time, 0.0, 1.0)
	return _state.paused_progress(recipe_id)
