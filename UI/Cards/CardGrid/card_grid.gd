extends HBoxContainer

signal card_selected(card_data: CardData)

@export var card_scene: PackedScene = preload("res://scenes/cards/card_view.tscn")
@onready var grid = $ScrollContainer/GridContainer

func set_cards(cards: Array[CardData]) -> void:
	for child in grid.get_children():
		child.queue_free()

	print("set_cards: ", cards.size())

	for card_data in cards:
		var card = card_scene.instantiate()
		card.custom_minimum_size = Vector2(130, 195)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.hover_enabled = false
		grid.add_child(card)
		card.set_card(card_data)
		card.card_pressed.connect(_on_card_pressed)

func _on_card_pressed(card_data: CardData) -> void:
	card_selected.emit(card_data)
