class_name LaboratoryRecipeCatalog
extends RefCounted

## Carga e indexa recetas. La progresión, el guardado y las señales siguen en
## LaboratoryState; esta clase sólo conoce el formato de los recursos.

static func load_all(directory_path: String) -> Array[Resource]:
	var recipes: Array[Resource] = []
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return recipes
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir():
			var path := ""
			if file.ends_with(".tres"):
				path = directory_path + file
			elif file.ends_with(".tres.remap"):
				path = directory_path + file.trim_suffix(".remap")
			if path != "":
				var recipe := load(path) as Resource
				if recipe != null:
					recipes.append(recipe)
		file = dir.get_next()
	dir.list_dir_end()
	return recipes

static func index_by_ingredient(recipes: Array[Resource]) -> Dictionary:
	var index: Dictionary = {}
	for recipe in recipes:
		for ingredient in recipe.ingredients:
			var item_id: String = ingredient["id"]
			if not index.has(item_id):
				index[item_id] = []
			index[item_id].append(recipe)
	return index
