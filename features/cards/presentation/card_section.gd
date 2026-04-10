extends Control

signal card_selected(card_data: CardData)

@onready var section_label = $Inner/SectionLabel
@onready var cards_wrapper = $Inner/CardsWrapper
@onready var cards_container = $Inner/CardsWrapper/CardsContainer

var card_scene = preload("res://features/cards/presentation/card_view.tscn")

func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	cards_wrapper.custom_minimum_size = Vector2(260, 180)
	cards_container.custom_minimum_size = Vector2(260, 180)

	if cards_container is HBoxContainer:
		cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
		cards_container.add_theme_constant_override("separation", 12)
	
func set_title(title: String) -> void:
	section_label.text = title

func set_cards(cards: Array) -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for card in cards:
		print("  adding card:", card.name)
		var card_view = card_scene.instantiate()
		cards_container.add_child(card_view)
		card_view.setup(card)
		card_view.card_pressed.connect(_on_card_pressed)

	print("  children after add =", cards_container.get_child_count())

	call_deferred("_debug_layout_sizes")
	
func _debug_layout_sizes() -> void:
	print("--- layout debug for ", name, " ---")
	print("section size = ", size)
	print("wrapper size = ", cards_wrapper.size)
	print("container size = ", cards_container.size)

	for child in cards_container.get_children():
		print("child ", child.name, " size = ", child.size)

func disable_cards() -> void:
	for child in cards_container.get_children():
		if child.has_method("set_disabled"):
			child.set_disabled(true)

func _on_card_pressed(card_data: CardData) -> void:
	card_selected.emit(card_data)
