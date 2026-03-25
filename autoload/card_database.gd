extends Node

var cards_by_id: Dictionary = {}

func _ready() -> void:
	_load_cards()

func _load_cards() -> void:
	var all_cards: Array[CardData] = [
		preload("res://data/cards/step.tres"),
		preload("res://data/cards/dash.tres"),
		preload("res://data/cards/strike.tres")
	]

	for card in all_cards:
		if card != null and card.id != "":
			cards_by_id[card.id] = card

func get_card(card_id: String) -> CardData:
	return cards_by_id.get(card_id, null)

func get_cards_from_ids(card_ids: Array[String]) -> Array[CardData]:
	var result: Array[CardData] = []

	print("CardDatabase received ids: ", card_ids)
	print("cards_by_id keys: ", cards_by_id.keys())

	for card_id in card_ids:
		var card := get_card(card_id)
		if card != null:
			result.append(card)
		else:
			push_warning("CardDatabase: card id not found -> %s" % card_id)

	return result
