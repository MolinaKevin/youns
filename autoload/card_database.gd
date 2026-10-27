extends Node

const GameDataValidator := preload("res://shared/game_data_validator.gd")
const DebugLogging := preload("res://shared/debug_logging.gd")
const CardCatalog := preload("res://shared/card_catalog.gd")

var cards_by_id: Dictionary = {}

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	var all_cards := CardCatalog.load_all()
	cards_by_id.clear()

	for card in all_cards:
		if card != null and card.id != "":
			cards_by_id[card.id] = card
	for error_text in GameDataValidator.card_errors(all_cards):
		push_error("CardDatabase: " + error_text)
	for error_text in GameDataValidator.youn_errors():
		push_error("GameData: " + error_text)
	for error_text in GameDataValidator.item_errors():
		push_error("GameData: " + error_text)

func get_card(card_id: String) -> CardData:
	return cards_by_id.get(card_id, null)

func get_cards_from_ids(card_ids: Array[String]) -> Array[CardData]:
	var result: Array[CardData] = []

	if DebugLogging.verbose_enabled():
		print("CardDatabase received ids: ", card_ids)
		print("cards_by_id keys: ", cards_by_id.keys())

	for card_id in card_ids:
		var card := get_card(card_id)
		if card != null:
			result.append(card)
		else:
			push_warning("CardDatabase: card id not found -> %s" % card_id)

	return result
