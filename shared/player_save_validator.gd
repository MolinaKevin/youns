class_name PlayerSaveValidator
extends RefCounted

## Sanea referencias persistidas que pudieron quedar obsoletas tras borrar o
## renombrar recursos. Conserva todo lo válido y devuelve los cambios hechos.

const CardCatalogScript := preload("res://shared/card_catalog.gd")
const InventoryServiceScript := preload("res://shared/inventory_service.gd")
const TypedResourceLoaderScript := preload("res://shared/typed_resource_loader.gd")
const RecipeCatalogScript := preload("res://shared/laboratory_recipe_catalog.gd")
const RECIPES_PATH := "res://data/lab_recipes/"
const FALLBACK_YOUN_PATH := "res://data/youns/nguruvilu.tres"
const FALLBACK_ZONE_ID := "hub"


static func sanitize(save: PlayerSaveData) -> PackedStringArray:
	var changes := PackedStringArray()
	if save == null:
		changes.append("La partida no existe.")
		return changes
	if not _is_youn_path(save.current_youn_path):
		save.current_youn_path = FALLBACK_YOUN_PATH
		changes.append("Youn actual inválido: se restauró el Youn inicial.")
	if not save.pending_evolution_path.is_empty() and not _is_youn_path(save.pending_evolution_path):
		save.pending_evolution_path = ""
		changes.append("Evolución pendiente inválida: se descartó.")
	var catalog := ZoneCatalog.new()
	if not catalog.has(save.saved_zone):
		save.saved_zone = FALLBACK_ZONE_ID
		save.saved_interior = ""
		save.has_saved_position = false
		changes.append("Zona guardada inválida: se volvió al hub.")
	if not save.saved_interior.is_empty() and not _is_packed_scene(save.saved_interior):
		save.saved_interior = ""
		changes.append("Interior guardado inválido: se volvió al exterior.")
	if save.world_progress == null:
		save.world_progress = WorldProgressData.new()
		changes.append("Progreso del mundo ausente: se recreó.")
	save.inventory_slots = maxi(1, save.inventory_slots)
	save.saved_day = maxi(1, save.saved_day)
	save.saved_hour = clampf(save.saved_hour, 0.0, 23.999)
	_sanitize_scalar_values(save, changes)
	_sanitize_card_ids(save, changes)
	_sanitize_inventory(save, changes)
	_sanitize_recipe_state(save, changes)
	_sanitize_discovered_evolutions(save, changes)
	return changes


static func _sanitize_scalar_values(save: PlayerSaveData, changes: PackedStringArray) -> void:
	var before := [save.gold, save.player_level, save.discipline, save.felicidad, save.care_mistakes, save.confianza,
		save.estres, save.aburrimiento, save.autocontrol, save.energia, save.salud,
		save.weight, save.hambre, save.ganas_bano, save.poop_pending, save.lives,
		save.lab_youn_growth_bonus, save.lab_max_hp_bonus, save.lab_data_per_cycle,
		save.lab_data_cost_reduction, save.lab_combat_recovery_percent]
	save.gold = maxi(0, save.gold)
	save.player_level = maxi(1, save.player_level)
	save.discipline = clampi(save.discipline, 0, 100)
	save.felicidad = clampi(save.felicidad, 0, 100)
	save.care_mistakes = clampi(save.care_mistakes, 0, 10)
	for key in ["confianza", "estres", "aburrimiento", "autocontrol", "energia", "salud", "hambre", "ganas_bano"]:
		save.set(key, clampi(int(save.get(key)), 0, 100))
	save.weight = maxf(0.0, save.weight)
	save.poop_pending = maxf(0.0, save.poop_pending)
	save.lives = maxi(0, save.lives)
	save.lab_youn_growth_bonus = maxi(0, save.lab_youn_growth_bonus)
	save.lab_max_hp_bonus = maxi(0, save.lab_max_hp_bonus)
	save.lab_data_per_cycle = maxi(1, save.lab_data_per_cycle)
	save.lab_data_cost_reduction = clampf(save.lab_data_cost_reduction, 0.0, 0.9)
	save.lab_combat_recovery_percent = clampf(save.lab_combat_recovery_percent, 0.0, 1.0)
	var after := [save.gold, save.player_level, save.discipline, save.felicidad, save.care_mistakes, save.confianza,
		save.estres, save.aburrimiento, save.autocontrol, save.energia, save.salud,
		save.weight, save.hambre, save.ganas_bano, save.poop_pending, save.lives,
		save.lab_youn_growth_bonus, save.lab_max_hp_bonus, save.lab_data_per_cycle,
		save.lab_data_cost_reduction, save.lab_combat_recovery_percent]
	if before != after:
		changes.append("Se limitaron valores numéricos inválidos de la partida.")


static func _sanitize_card_ids(save: PlayerSaveData, changes: PackedStringArray) -> void:
	var known := CardCatalogScript.known_ids()
	var owned := _known_ids(save.owned_card_ids, known)
	if owned.size() != save.owned_card_ids.size():
		save.owned_card_ids = owned
		changes.append("Se quitaron cartas inexistentes de la colección.")
	var equipped := _known_ids(save.equipped_deck_ids, known)
	if equipped.size() != save.equipped_deck_ids.size():
		save.equipped_deck_ids = equipped
		changes.append("Se quitaron cartas inexistentes del mazo inicial.")
	var deck: Array[CardData] = []
	for card in save.deck:
		if card != null and known.has(card.id):
			deck.append(card)
	if deck.size() != save.deck.size():
		save.deck = deck
		changes.append("Se quitaron cartas inválidas del mazo guardado.")
	var inherited: Array[CardData] = []
	for card in save.saved_cards:
		if card != null and known.has(card.id):
			inherited.append(card)
	if inherited.size() != save.saved_cards.size():
		save.saved_cards = inherited
		changes.append("Se quitaron cartas reencarnadas inválidas.")


static func _sanitize_inventory(save: PlayerSaveData, changes: PackedStringArray) -> void:
	var sanitized := InventoryServiceScript.sanitize_entries(save.inventory_items, save.inventory_slots)
	if sanitized != save.inventory_items:
		save.inventory_items = sanitized
		changes.append("Se normalizó el inventario guardado.")


static func _sanitize_recipe_state(save: PlayerSaveData, changes: PackedStringArray) -> void:
	var known := {}
	for recipe in RecipeCatalogScript.load_all(RECIPES_PATH):
		if not str(recipe.id).is_empty():
			known[recipe.id] = true
	var unlocked := _known_ids(save.unlocked_recipe_ids, known)
	var completed := _known_ids(save.completed_recipe_ids, known)
	if unlocked != save.unlocked_recipe_ids or completed != save.completed_recipe_ids:
		save.unlocked_recipe_ids = unlocked
		save.completed_recipe_ids = completed
		changes.append("Se quitaron recetas inexistentes del progreso.")
	var progress := {}
	for recipe_id in save.lab_recipe_progress:
		if known.has(recipe_id):
			progress[recipe_id] = clampf(float(save.lab_recipe_progress[recipe_id]), 0.0, 1.0)
	if progress != save.lab_recipe_progress:
		save.lab_recipe_progress = progress
		changes.append("Se normalizó el avance de recetas guardado.")
	if not save.lab_active_recipe_id.is_empty() and not known.has(save.lab_active_recipe_id):
		save.lab_active_recipe_id = ""
		changes.append("Se descartó una receta activa inexistente.")


static func _sanitize_discovered_evolutions(save: PlayerSaveData, changes: PackedStringArray) -> void:
	var known := {}
	for youn in YounCatalog.all():
		known[youn.id] = youn
	var discovered := {}
	for youn_id in save.discovered_evolutions:
		var youn := known.get(youn_id) as YounData
		if youn == null:
			continue
		var indices: Array = []
		for index in save.discovered_evolutions[youn_id]:
			var numeric_index := int(index)
			if numeric_index >= 0 and numeric_index < youn.evolution_conditions.size() and not indices.has(numeric_index):
				indices.append(numeric_index)
		discovered[youn_id] = indices
	if discovered != save.discovered_evolutions:
		save.discovered_evolutions = discovered
		changes.append("Se normalizaron evoluciones descubiertas inválidas.")


static func _known_ids(ids: Array[String], known: Dictionary) -> Array[String]:
	var valid: Array[String] = []
	for card_id in ids:
		if known.has(card_id):
			valid.append(card_id)
	return valid


static func _is_youn_path(path: String) -> bool:
	return TypedResourceLoaderScript.youn(path) != null


static func _is_packed_scene(path: String) -> bool:
	return TypedResourceLoaderScript.packed_scene(path) != null
