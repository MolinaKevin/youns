extends HBoxContainer

signal card_selected(card_data: CardData)

@export var card_scene: PackedScene = preload("res://UI/Cards/Collection/collection_card.tscn")
@onready var grid = $ScrollContainer/GridContainer

func set_cards(cards: Array[CardData]) -> void:
	for child in grid.get_children():
		child.queue_free()

	print("set_cards: ", cards.size())

	for card_data in cards:
		var card = card_scene.instantiate()
		grid.add_child(card)
		card.set_card(card_data)
		card.pressed.connect(_on_card_pressed.bind(card_data))

func _on_card_pressed(card_data: CardData) -> void:
	card_selected.emit(card_data)
