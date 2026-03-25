extends Control

@onready var label = $Label

func show_card(card_data: CardData) -> void:
	if card_data == null:
		label.text = ""
		return

	label.text = "%s\nCost: %d\nType: %s\nRange: %d\nDamage: %d" % [
		card_data.name,
		card_data.cost,
		card_data.card_type,
		card_data.card_range,
		card_data.damage
	]
