class_name LaboratoryRecipeRules
extends RefCounted

## Reglas de ingredientes y desbloqueo de recetas: qué hace falta para activar
## una receta y cuándo una receta nueva queda disponible. Separado del ciclo
## temporal (LaboratoryRecipeRuntime) y del autoload, que sigue siendo dueño
## de las colecciones privadas (_pending_output, _unlocked_columns) y de las
## señales: esta clase las toca a través de los métodos públicos de `_state`.

var _state

func _init(state) -> void:
	_state = state

func has_ingredients(recipe: LabRecipe) -> bool:
	if not _state.progress().has_gold(recipe.gold_cost):
		return false
	return has_enough_ingredients(recipe.ingredients)

func has_enough_ingredients(ingredients: Array) -> bool:
	for ing in ingredients:
		if _state.output_count(str(ing["id"])) < ingredient_amount(ing):
			return false
	return true

func ingredient_amount(ingredient: Dictionary) -> int:
	var amount := int(ingredient.get("amount", 0))
	var save: PlayerSaveData = _state.progress().save()
	if str(ingredient.get("id", "")) == "datos" and save != null:
		amount = ceili(float(amount) * (1.0 - save.lab_data_cost_reduction))
	return maxi(1, amount)

func consume_ingredients(recipe: LabRecipe) -> void:
	_state.progress().spend_gold(recipe.gold_cost)
	for ing in recipe.ingredients:
		_state.reduce_output(str(ing["id"]), ingredient_amount(ing))

func unlock_recipe(recipe_id: String) -> void:
	if not _state.progress().unlock(recipe_id):
		return
	var recipe: LabRecipe = _state.get_recipe_by_id(recipe_id)
	if recipe == null:
		return
	_state.unlock_column(recipe.location, recipe.action_type)
	if _state.is_loaded:
		_state.recipe_unlocked.emit(recipe)

func check_indirect_unlocks(produced_item_id: String) -> void:
	for recipe in _state.recipes_for_ingredient(produced_item_id):
		if recipe.needs_research or _state.is_recipe_unlocked(recipe.id) or _state.is_recipe_completed(recipe.id):
			continue
		if has_enough_ingredients(recipe.ingredients):
			unlock_recipe(recipe.id)
