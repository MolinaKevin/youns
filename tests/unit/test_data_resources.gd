extends GutTest

const LabReward := preload("res://data/lab_reward.gd")
const LabRecipeAction := preload("res://data/lab_recipe_action.gd")
const WorldConstructionCatalog := preload("res://data/world/world_construction_catalog.gd")
const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")
const DATA_DIR := "res://data"
const CARDS_DIR := "res://data/cards"
const ITEMS_DIR := "res://data/items"
const RECIPES_DIR := "res://data/lab_recipes"
const YOUNS_DIR := "res://data/youns"
const ZONES_DIR := "res://data/zones/definitions"
const INTELLIGENCES_DIR := "res://data/youns/intelligences"


func _resource_paths(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		var path := directory.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				paths.append_array(_resource_paths(path))
		elif name.ends_with(".tres"):
			paths.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return paths


func test_todos_los_recursos_de_datos_existen_y_cargan() -> void:
	var paths := _resource_paths(DATA_DIR)

	assert_gt(paths.size(), 0, "data/ debería contener recursos editables")
	for path in paths:
		assert_true(ResourceLoader.exists(path), "No existe: %s" % path)
		assert_not_null(ResourceLoader.load(path), "No carga: %s" % path)


func test_cartas_e_items_tienen_nombre_localizado() -> void:
	for path in _resource_paths(DATA_DIR):
		var resource := ResourceLoader.load(path)
		if resource is CardData:
			_assert_localized_name("card.name", resource.id, path)
			_assert_card_effects(resource, path)
		elif resource is ItemData:
			_assert_localized_name("item.name", resource.id, path)


func _assert_card_effects(card: CardData, path: String) -> void:
	for action in [card.top, card.bottom]:
		if action == null:
			continue
		for line in action.lines:
			assert_true(CombatEffect.is_known_zone(line.puddle_effect), "Efecto de charco desconocido '%s' en %s" % [line.puddle_effect, path])
			assert_true(CombatEffect.is_known_status(line.status_effect, true), "Estado desconocido '%s' en %s" % [line.status_effect, path])


func test_recetas_tienen_nombre_y_tipo_localizados() -> void:
	for path in _resource_paths(DATA_DIR):
		var resource := ResourceLoader.load(path)
		if resource is LabRecipe:
			_assert_localized_name("recipe.name", resource.id, path)
			_assert_localized_key("lab.action.%s" % resource.action_type, path)


func test_catalogos_de_cartas_e_items_tienen_ids_unicos() -> void:
	_assert_unique_resource_ids(CARDS_DIR, CardData)
	_assert_unique_resource_ids(ITEMS_DIR, ItemData)


func test_catalogos_de_recetas_youns_y_zonas_tienen_ids_unicos() -> void:
	_assert_unique_resource_ids(RECIPES_DIR, LabRecipe)
	_assert_unique_resource_ids(YOUNS_DIR, YounData)
	_assert_unique_resource_ids(ZONES_DIR, ZoneDefinition)


func test_referencias_de_recetas_apuntan_a_recetas_existentes() -> void:
	var recipes := _resources_by_id(RECIPES_DIR, LabRecipe)
	for recipe_id in recipes:
		var recipe: LabRecipe = recipes[recipe_id]
		_assert_recipe_references(recipe, recipes)


func test_youns_referencian_inteligencias_y_evoluciones_validas() -> void:
	var intelligences := _resources_by_id(INTELLIGENCES_DIR, IntelligenceData)
	for path in _resource_paths(YOUNS_DIR):
		var youn := ResourceLoader.load(path) as YounData
		if youn == null:
			continue
		for intelligence_id in youn.intelligences:
			assert_true(intelligences.has(intelligence_id), "Inteligencia inexistente '%s' en %s" % [intelligence_id, path])
		for evolution_path in youn.evolves_to:
			assert_true(ResourceLoader.exists(evolution_path), "Evolución inexistente '%s' en %s" % [evolution_path, path])
			assert_true(ResourceLoader.load(evolution_path) is YounData, "La evolución debe ser un YounData: %s" % evolution_path)


func test_zonas_tienen_escena_y_conexiones_bidireccionales() -> void:
	var zones := _resources_by_id(ZONES_DIR, ZoneDefinition)
	for zone_id in zones:
		var zone: ZoneDefinition = zones[zone_id]
		assert_false(zone.scene_path.is_empty(), "La zona %s no tiene escena" % zone_id)
		assert_true(ResourceLoader.exists(zone.scene_path), "No existe la escena de %s: %s" % [zone_id, zone.scene_path])
		for connected_id in zone.connections:
			assert_true(zones.has(connected_id), "Zona inexistente '%s' conectada desde %s" % [connected_id, zone_id])
			if zones.has(connected_id):
				var connected_zone: ZoneDefinition = zones[connected_id]
				assert_true(connected_zone.connections.has(zone_id), "Falta el retorno %s → %s" % [connected_id, zone_id])


func test_construcciones_del_mundo_referencian_recetas_y_zonas_validas() -> void:
	var recipes := _resources_by_id(RECIPES_DIR, LabRecipe)
	var zones := _resources_by_id(ZONES_DIR, ZoneDefinition)
	var catalog := WorldConstructionCatalog.new()
	assert_eq(catalog.validate().size(), 0)
	for construction in catalog.all():
		assert_true(recipes.has(construction.unlock_recipe_id), "Receta inexistente en construcción %s" % construction.id)
		assert_true(zones.has(construction.zone_id), "Zona inexistente en construcción %s" % construction.id)


func test_card_database_registra_todas_las_cartas_y_solo_esas() -> void:
	var cards_on_disk := _resources_by_id(CARDS_DIR, CardData)

	assert_eq(
		CardDatabase.cards_by_id.size(),
		cards_on_disk.size(),
		"CardDatabase debe tener exactamente las cartas de data/cards",
	)
	for card_id in cards_on_disk:
		var card_on_disk: CardData = cards_on_disk[card_id]
		var registered := CardDatabase.get_card(card_id)
		assert_not_null(registered, "CardDatabase no registró: %s" % card_on_disk.resource_path)
		if registered != null:
			assert_eq(
				registered.resource_path,
				card_on_disk.resource_path,
				"CardDatabase apunta a un recurso distinto para: %s" % card_id,
			)


func _assert_localized_name(prefix: String, resource_id: String, path: String) -> void:
	assert_false(resource_id.is_empty(), "El recurso debe tener id: %s" % path)
	_assert_localized_key("%s.%s" % [prefix, resource_id], path)


func _assert_localized_key(key: String, path: String) -> void:
	for language in LocalizationState.SUPPORTED_LANGUAGES:
		var translations: Dictionary = LocalizationState._translations.get(language, {})
		assert_true(translations.has(key), "Falta %s en %s (%s)" % [key, language, path])


func _assert_recipe_references(recipe: LabRecipe, recipes: Dictionary) -> void:
	assert_true(LabRecipeAction.is_known(recipe.action_type), "Tipo de acción desconocido en %s: %s" % [recipe.resource_path, recipe.action_type])
	_assert_reward_reference(recipe.reward, recipe.resource_path, recipes)
	for reward in recipe.extra_rewards:
		_assert_reward_reference(reward, recipe.resource_path, recipes)
	for ingredient in recipe.ingredients:
		var item_id := str(ingredient.get("id", ""))
		assert_false(item_id.is_empty(), "Ingrediente sin id en %s" % recipe.resource_path)
		assert_gt(int(ingredient.get("amount", 0)), 0, "Ingrediente sin cantidad válida en %s" % recipe.resource_path)


func _assert_reward_reference(reward: Dictionary, path: String, recipes: Dictionary) -> void:
	var reward_type := LabReward.type_of(reward)
	assert_false(reward_type.is_empty(), "Recompensa sin tipo en %s" % path)
	assert_true(LabReward.is_known(reward), "Tipo de recompensa desconocido '%s' en %s" % [reward_type, path])
	_assert_reward_shape(reward, path)
	if reward_type == LabReward.UNLOCK_RECIPE:
		var recipe_id := str(reward.get("id", ""))
		assert_true(recipes.has(recipe_id), "Receta inexistente '%s' en %s" % [recipe_id, path])
	elif reward_type == LabReward.ITEM or reward_type == LabReward.WORLD_BRIDGE:
		assert_false(str(reward.get("id", "")).is_empty(), "Recompensa %s sin id en %s" % [reward_type, path])
	if reward_type == LabReward.ITEM:
		assert_gt(int(reward.get("amount", 0)), 0, "Ítem sin cantidad válida en %s" % path)
	elif reward_type in [LabReward.YOUN_GROWTH_BONUS, LabReward.MATERIAL_PRODUCTION, LabReward.MAX_HP]:
		assert_gt(int(reward.get("value", 0)), 0, "Recompensa sin valor positivo en %s" % path)


func _assert_reward_shape(reward: Dictionary, path: String) -> void:
	var expected: Array = LabReward.expected_fields(LabReward.type_of(reward))
	for field in expected:
		assert_true(reward.has(field), "Falta '%s' en la recompensa de %s" % [field, path])
	for field in reward:
		assert_true(field in expected, "Campo inesperado '%s' en la recompensa de %s" % [field, path])


func _assert_unique_resource_ids(directory: String, resource_type: Variant) -> void:
	_resources_by_id(directory, resource_type)


func _resources_by_id(directory: String, resource_type: Variant) -> Dictionary:
	var resources_by_id := {}
	for path in _resource_paths(directory):
		var resource := ResourceLoader.load(path)
		if not is_instance_of(resource, resource_type):
			continue
		var resource_id: String = resource.id
		assert_false(resource_id.is_empty(), "El recurso debe tener id: %s" % path)
		assert_false(resources_by_id.has(resource_id), "Id repetido '%s': %s" % [resource_id, path])
		resources_by_id[resource_id] = resource
	return resources_by_id
