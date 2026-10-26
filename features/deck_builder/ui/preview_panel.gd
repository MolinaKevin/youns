extends Control

@onready var card_image = $VBox/CardImage
@onready var info_label = $VBox/InfoLabel

func show_card(card_data: CardData) -> void:
	if card_data == null:
		card_image.texture = CardText.FALLBACK_IMAGE
		info_label.text = LocalizationState.t("deck.select_card")
		return

	card_image.texture = card_data.image if card_data.image != null else CardText.FALLBACK_IMAGE
	info_label.text = LocalizationState.t("deck.preview", [
		LocalizationState.card_name(card_data.id, card_data.name),
		card_data.initiative,
		CardText.half_summary(card_data.top, "\n"),
		CardText.half_summary(card_data.bottom, "\n"),
	])
