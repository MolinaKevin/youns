class_name PlayerSaveValidator
extends RefCounted

## Sanea referencias persistidas que pudieron quedar obsoletas tras borrar o
## renombrar recursos. Conserva todo lo válido y devuelve los cambios hechos.

const CardCatalog := preload("res://shared/card_catalog.gd")
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
	_sanitize_card_ids(save, changes)
	_sanitize_inventory(save, changes)
	return changes


static func _sanitize_card_ids(save: PlayerSaveData, changes: PackedStringArray) -> void:
	var known := CardCatalog.known_ids()
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
	var valid: Array[Dictionary] = []
	for entry in save.inventory_items:
		var path := str(entry.get("data_path", ""))
		var count := int(entry.get("count", 0))
		if count > 0 and _is_item_path(path):
			valid.append(entry)
	if valid.size() != save.inventory_items.size():
		save.inventory_items = valid
		changes.append("Se quitaron entradas de inventario inválidas.")


static func _known_ids(ids: Array[String], known: Dictionary) -> Array[String]:
	var valid: Array[String] = []
	for card_id in ids:
		if known.has(card_id):
			valid.append(card_id)
	return valid


static func _is_youn_path(path: String) -> bool:
	return ResourceLoader.exists(path) and load(path) is YounData


static func _is_item_path(path: String) -> bool:
	return ResourceLoader.exists(path) and load(path) is ItemData


static func _is_packed_scene(path: String) -> bool:
	return ResourceLoader.exists(path) and load(path) is PackedScene
