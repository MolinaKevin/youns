extends Node

const GameDataValidatorScript := preload("res://shared/game_data_validator.gd")
const DebugLog := preload("res://shared/debug_logging.gd")
const CardCatalogScript := preload("res://shared/card_catalog.gd")

var cards_by_id: Dictionary = {}

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	var all_cards := CardCatalogScript.load_all()
	cards_by_id.clear()

	for card in all_cards:
		if card != null and card.id != "":
			cards_by_id[card.id] = card
	for error_text in GameDataValidatorScript.card_errors(all_cards):
		push_error("CardDatabase: " + error_text)
	for error_text in GameDataValidatorScript.youn_errors():
		push_error("GameData: " + error_text)
	for error_text in GameDataValidatorScript.item_errors():
		push_error("GameData: " + error_text)

func get_card(card_id: String) -> CardData:
	return cards_by_id.get(card_id, null)

func get_cards_from_ids(card_ids: Array[String]) -> Array[CardData]:
	var result: Array[CardData] = []

	if DebugLog.verbose_enabled():
		print("[CardDatabase] IDs solicitados: %s | catálogo: %d cartas." % [card_ids, cards_by_id.size()])

	for card_id in card_ids:
		var card := get_card(card_id)
		if card != null:
			result.append(card)
		else:
			push_warning("CardDatabase: card id not found -> %s" % card_id)

	return result
