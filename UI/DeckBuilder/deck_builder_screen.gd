extends Control

@onready var card_grid = $MarginContainer/MainVBox/Body/LeftPanel/CardGrid
@onready var preview_panel = $MarginContainer/MainVBox/Body/RightPanel/PreviewPanel
@onready var deck_list = $MarginContainer/MainVBox/Body/RightPanel/DeckScroll/DeckList
@onready var deck_count_label = $MarginContainer/MainVBox/Body/RightPanel/DeckHeader/DeckCountLabel
@onready var save_button = $MarginContainer/MainVBox/Header/SaveButton
@onready var add_button = $MarginContainer/MainVBox/Body/RightPanel/PreviewPanel/VBox/AddButton

var owned_cards: Array[CardData] = []
var current_deck: Array[String] = []
var selected_card: CardData = null

func _ready() -> void:
	owned_cards = _get_owned_cards()
	current_deck = GameState.player_save.equipped_deck_ids.duplicate()

	card_grid.set_cards(owned_cards)
	card_grid.card_selected.connect(_on_collection_card_selected)
	add_button.pressed.connect(_on_add_pressed)
	save_button.pressed.connect(_on_save_pressed)

	_refresh_deck_panel()

	if owned_cards.size() > 0:
		_on_collection_card_selected(owned_cards[0])

func _on_collection_card_selected(card_data: CardData) -> void:
	selected_card = card_data
	preview_panel.show_card(card_data)
	add_button.disabled = false

func _on_add_pressed() -> void:
	if selected_card == null:
		return
	current_deck.append(selected_card.id)
	_refresh_deck_panel()

func _remove_card_from_deck(index: int) -> void:
	current_deck.remove_at(index)
	_refresh_deck_panel()

func _refresh_deck_panel() -> void:
	for child in deck_list.get_children():
		child.queue_free()

	deck_count_label.text = "%d cartas" % current_deck.size()

	for i in current_deck.size():
		var card_id = current_deck[i]
		var card_data: CardData = CardDatabase.get_card(card_id)

		var row = HBoxContainer.new()
		deck_list.add_child(row)

		var lbl = Label.new()
		lbl.text = card_data.name if card_data != null else card_id
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn = Button.new()
		btn.text = "X"
		btn.pressed.connect(_remove_card_from_deck.bind(i))
		row.add_child(btn)

func _on_save_pressed() -> void:
	GameState.player_save.equipped_deck_ids = current_deck.duplicate()
	GameState.save_player_save()

func _get_owned_cards() -> Array[CardData]:
	if GameState.player_save == null:
		return []
	return CardDatabase.get_cards_from_ids(GameState.player_save.owned_card_ids)
