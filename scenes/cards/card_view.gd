extends Control

signal card_pressed(card_data: CardData)

@onready var card_button = $CardInner/CardFrame/CardButton
@onready var card_label = $CardInner/CardLabel
@onready var card_inner = $CardInner
@onready var card_frame = $CardInner/CardFrame

var card_data: CardData
var pending_setup_card: CardData

func _ready() -> void:
	custom_minimum_size = Vector2(110, 170)
	card_inner.custom_minimum_size = Vector2(110, 170)
	card_frame.custom_minimum_size = Vector2(110, 145)
	card_button.custom_minimum_size = Vector2(110, 145)

	card_button.pressed.connect(_on_card_button_pressed)

	if pending_setup_card != null:
		_apply_card_data(pending_setup_card)
		pending_setup_card = null

func setup(card: CardData) -> void:
	print("CardView.setup() ->", card.name)
	card_data = card

	if not is_node_ready():
		print("  node not ready yet, storing pending card:", card.name)
		pending_setup_card = card
		return

	_apply_card_data(card)

func _apply_card_data(card: CardData) -> void:
	print("CardView._apply_card_data() ->", card.name)
	card_label.text = "%s | %d" % [
		card.name,
		card.cost
	]

	if card.image:
		print("  image OK for", card.name)
		card_button.texture_normal = card.image
	else:
		print("  image MISSING for", card.name)

func set_disabled(value: bool) -> void:
	card_button.disabled = value

func _on_card_button_pressed() -> void:
	card_pressed.emit(card_data)
