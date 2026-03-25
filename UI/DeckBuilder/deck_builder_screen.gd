extends Control

@onready var card_grid = $MarginContainer/MainVBox/Body/LeftPanel/CardGrid
@onready var preview_panel = $MarginContainer/MainVBox/Body/PreviewPanel

var owned_cards: Array[CardData] = []

func _ready() -> void:
	owned_cards = _get_owned_cards()
	print("owned_cards: ", owned_cards.size())

	card_grid.set_cards(owned_cards)
	card_grid.card_selected.connect(_on_card_selected)

	if owned_cards.size() > 0:
		_on_card_selected(owned_cards[0])

func _on_card_selected(card_data: CardData) -> void:
	preview_panel.show_card(card_data)

func _get_owned_cards() -> Array[CardData]:
	if GameState.player_save == null:
		print("GameState.player_save is NULL")
		return []

	print("owned ids: ", GameState.player_save.owned_card_ids)

	var cards := CardDatabase.get_cards_from_ids(GameState.player_save.owned_card_ids)
	print("resolved cards: ", cards.size())

	return cards
