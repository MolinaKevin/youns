extends Control

const FALLBACK_IMAGE = preload("res://assets/cards/test.png")

@onready var card_image = $VBox/CardImage
@onready var info_label = $VBox/InfoLabel

func show_card(card_data: CardData) -> void:
	if card_data == null:
		card_image.texture = FALLBACK_IMAGE
		info_label.text = LocalizationState.t("deck.select_card")
		return

	card_image.texture = card_data.image if card_data.image != null else FALLBACK_IMAGE
	info_label.text = LocalizationState.t("deck.preview", [
		LocalizationState.card_name(card_data.id, card_data.name),
		card_data.cost,
		LocalizationState.card_type_name(card_data.card_type),
		LocalizationState.card_description(card_data.id, card_data.description)
	])
