extends Control

@onready var card_grid = $MarginContainer/MainVBox/Body/LeftPanel/CardGrid
@onready var preview_panel = $MarginContainer/MainVBox/Body/RightPanel/PreviewPanel
@onready var deck_list = $MarginContainer/MainVBox/Body/RightPanel/DeckScroll/DeckList
@onready var title_label = $MarginContainer/MainVBox/Header/TitleLabel
@onready var deck_count_label = $MarginContainer/MainVBox/Body/RightPanel/DeckHeader/DeckCountLabel
@onready var deck_title_label = $MarginContainer/MainVBox/Body/RightPanel/DeckHeader/DeckTitleLabel
@onready var save_button = $MarginContainer/MainVBox/Header/SaveButton
@onready var add_button = $MarginContainer/MainVBox/Body/RightPanel/PreviewPanel/VBox/AddButton

var owned_cards: Array[CardData] = []
## Copias propias (ver DeckRules): pueden traer cambios de las evoluciones.
var current_deck: Array[CardData] = []
var selected_card: CardData = null

func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LocalizationState.language_changed.connect(_apply_localized_text)
	owned_cards = _get_owned_cards()
	current_deck = DeckRules.cards(GameState.player_save).duplicate()

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
	current_deck.append(selected_card.clone())
	_refresh_deck_panel()

func _remove_card_from_deck(index: int) -> void:
	current_deck.remove_at(index)
	_refresh_deck_panel()

func _refresh_deck_panel() -> void:
	for child in deck_list.get_children():
		child.queue_free()

	deck_count_label.text = LocalizationState.t("deck.count", [current_deck.size()])
	_apply_localized_text()

	for i in current_deck.size():
		var card_data: CardData = current_deck[i]

		var row = HBoxContainer.new()
		deck_list.add_child(row)

		var lbl = Label.new()
		lbl.text = LocalizationState.card_name(card_data.id, card_data.name)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn = Button.new()
		btn.text = LocalizationState.t("deck.remove")
		btn.pressed.connect(_remove_card_from_deck.bind(i))
		row.add_child(btn)

func _on_save_pressed() -> void:
	GameState.player_save.deck = current_deck.duplicate()

## Las cartas que se pueden sumar al mazo: primero las guardadas de vidas
## anteriores (con sus cambios), después la colección.
func _get_owned_cards() -> Array[CardData]:
	if GameState.player_save == null:
		return []
	var cards: Array[CardData] = []
	cards.append_array(GameState.player_save.saved_cards)
	cards.append_array(CardDatabase.get_cards_from_ids(GameState.player_save.owned_card_ids))
	return cards

func _apply_localized_text(_language: String = "") -> void:
	title_label.text = LocalizationState.t("deck.title")
	save_button.text = LocalizationState.t("deck.save")
	add_button.text = LocalizationState.t("deck.add")
	deck_title_label.text = LocalizationState.t("deck.my_deck")
	deck_count_label.text = LocalizationState.t("deck.count", [current_deck.size()])
	if selected_card == null:
		preview_panel.show_card(null)
	elif selected_card != null:
		preview_panel.show_card(selected_card)
