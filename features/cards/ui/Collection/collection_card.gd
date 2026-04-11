extends Button

const FALLBACK_IMAGE = preload("res://assets/cards/test.png")

var card_data: CardData

@onready var art = $MarginContainer/VBoxContainer/TextureRect
@onready var name_label = $MarginContainer/VBoxContainer/NameLabel
@onready var desc_label = $MarginContainer/VBoxContainer/DescLabel

func set_card(data: CardData) -> void:
	card_data = data
	if card_data == null:
		art.texture = FALLBACK_IMAGE
		name_label.text = ""
		desc_label.text = ""
		return

	art.texture = card_data.image if card_data.image != null else FALLBACK_IMAGE
	name_label.text = LocalizationState.card_name(card_data.id, card_data.name)
	desc_label.text = LocalizationState.card_description(card_data.id, card_data.description)
