extends Control

const FALLBACK_IMAGE = preload("res://assets/cards/test.png")

@onready var card_image = $VBox/CardImage
@onready var info_label = $VBox/InfoLabel

func show_card(card_data: CardData) -> void:
	if card_data == null:
		card_image.texture = FALLBACK_IMAGE
		info_label.text = "Seleccioná una carta"
		return

	card_image.texture = card_data.image if card_data.image != null else FALLBACK_IMAGE
	info_label.text = "%s\nCosto: %d | Tipo: %s\n\n%s" % [
		card_data.name,
		card_data.cost,
		card_data.card_type,
		card_data.description
	]
