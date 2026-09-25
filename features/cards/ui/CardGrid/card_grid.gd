extends HBoxContainer

signal card_selected(card_data: CardData)

@export var card_scene: PackedScene = preload("res://features/cards/presentation/card_view.tscn")
@onready var grid = $ScrollContainer/GridContainer

func set_cards(cards: Array[CardData]) -> void:
	for child in grid.get_children():
		child.queue_free()

	print("set_cards: ", cards.size())

	for card_data in cards:
		# La carta tiene un diseño fijo de 195x293: se escala en vez de achicarla.
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(130, 195)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(holder)
		var card = card_scene.instantiate()
		card.scale = Vector2(130.0 / 195.0, 130.0 / 195.0)
		card.hover_enabled = false
		holder.add_child(card)
		card.set_card(card_data)
		card.card_pressed.connect(_on_card_pressed)

func _on_card_pressed(card_data: CardData) -> void:
	card_selected.emit(card_data)
