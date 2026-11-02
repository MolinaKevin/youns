class_name LaboratoryRecipeCatalog
extends RefCounted

## Carga e indexa recetas. La progresión, el guardado y las señales siguen en
## LaboratoryState; esta clase sólo conoce el formato de los recursos.

static func load_all(directory_path: String) -> Array[LabRecipe]:
	var recipes: Array[LabRecipe] = []
	for path in ResourceCatalogLoader.resource_paths(directory_path):
		var recipe := TypedResourceLoader.lab_recipe(path)
		if recipe != null:
			recipes.append(recipe)
	return recipes

static func index_by_ingredient(recipes: Array[LabRecipe]) -> Dictionary:
	var index: Dictionary = {}
	for recipe in recipes:
		for ingredient in recipe.ingredients:
			var item_id: String = ingredient["id"]
			if not index.has(item_id):
				index[item_id] = []
			index[item_id].append(recipe)
	return index
