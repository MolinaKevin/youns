class_name GameDataValidator
extends RefCounted

## Validaciones que deben correr al cargar catálogos de recursos, además de
## las pruebas. Dan un error temprano al editar un .tres a mano.

const LabRecipeAction := preload("res://data/lab_recipe_action.gd")
const LabReward := preload("res://data/lab_reward.gd")
const YounCatalog := preload("res://shared/youn_catalog.gd")
const ItemCatalog := preload("res://shared/item_catalog.gd")


static func card_errors(cards: Array[CardData]) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for card in cards:
		if card == null:
			errors.append("Carta nula en CardDatabase.")
			continue
		var path := card.resource_path
		if card.id.is_empty():
			errors.append("Carta sin id: %s" % path)
		elif ids.has(card.id):
			errors.append("Id de carta repetido '%s': %s y %s" % [card.id, ids[card.id], path])
		else:
			ids[card.id] = path
		for side in [card.top, card.bottom]:
			if side == null:
				continue
			for line in side.lines:
				if line == null:
					errors.append("Carta %s tiene una línea nula." % path)
	return errors


static func recipe_errors(recipes: Array[Resource]) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for resource in recipes:
		var recipe := resource as LabRecipe
		if recipe == null:
			errors.append("Recurso de laboratorio inválido: %s" % resource.resource_path)
			continue
		var path := recipe.resource_path
		if recipe.id.is_empty():
			errors.append("Receta sin id: %s" % path)
		elif ids.has(recipe.id):
			errors.append("Id de receta repetido '%s': %s y %s" % [recipe.id, ids[recipe.id], path])
		else:
			ids[recipe.id] = path
		if not LabRecipeAction.is_known(recipe.action_type):
			errors.append("Acción de receta desconocida '%s' en %s" % [recipe.action_type, path])
		for ingredient in recipe.ingredients:
			if str(ingredient.get("id", "")).is_empty() or int(ingredient.get("amount", 0)) <= 0:
				errors.append("Ingrediente inválido en %s" % path)
		for reward in [recipe.reward] + recipe.extra_rewards:
			if not LabReward.is_known(reward):
				errors.append("Recompensa inválida en %s" % path)
	return errors


static func youn_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for youn in YounCatalog.all():
		var path := youn.resource_path
		if youn.id.is_empty():
			errors.append("Youn sin id: %s" % path)
		elif ids.has(youn.id):
			errors.append("Id de Youn repetido '%s': %s y %s" % [youn.id, ids[youn.id], path])
		else:
			ids[youn.id] = path
		for target_path in youn.evolves_to:
			if YounCatalog.by_path(target_path) == null:
				errors.append("Evolución inexistente '%s' en %s" % [target_path, path])
	return errors


static func item_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for item in ItemCatalog.all():
		var path := item.resource_path
		if item.id.is_empty():
			errors.append("Ítem sin id: %s" % path)
		elif ids.has(item.id):
			errors.append("Id de ítem repetido '%s': %s y %s" % [item.id, ids[item.id], path])
		else:
			ids[item.id] = path
		for effect in item.effects:
			if effect == null:
				errors.append("Ítem con efecto nulo: %s" % path)
	return errors


static func zone_graph_errors(catalog: ZoneCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	for id in catalog.ids():
		var definition := catalog.definition(id)
		if definition == null:
			continue
		for neighbor_id in definition.connections:
			var neighbor := catalog.definition(neighbor_id)
			if neighbor != null and not neighbor.connections.has(id):
				errors.append("Conexión de zona no recíproca: %s → %s." % [id, neighbor_id])
	return errors
