extends Control

signal card_selected(card_data: CardData)

@onready var section_label = $Inner/SectionLabel
@onready var cards_wrapper = $Inner/CardsWrapper
@onready var cards_container = $Inner/CardsWrapper/CardsContainer

var card_scene = preload("res://scenes/cards/card_view.tscn")
var hidden_y := 0.0
var shown_y := 0.0
var current_tween: Tween
var is_shown := false

func _ready() -> void:
	custom_minimum_size = Vector2(260, 260)
	cards_wrapper.custom_minimum_size = Vector2(260, 180)
	cards_container.custom_minimum_size = Vector2(260, 180)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	print("CardSection ready:", name)
	print(name, " wrapper y = ", cards_wrapper.position.y)
	
	if cards_container is HBoxContainer:
		cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
		cards_container.add_theme_constant_override("separation", 12)
	
func set_title(title: String) -> void:
	section_label.text = title

func set_cards(cards: Array) -> void:
	for child in cards_container.get_children():
		child.free()

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

func hide_cards_initially() -> void:
	cards_wrapper.position.y = hidden_y
	is_shown = false
	print(name, " hidden -> y = ", cards_wrapper.position.y)

func show_cards() -> void:
	if is_shown:
		return
	is_shown = true
	animate_cards_to(shown_y)

func hide_cards() -> void:
	if not is_shown:
		return
	is_shown = false
	animate_cards_to(hidden_y)

func animate_cards_to(target_y: float) -> void:
	if current_tween and is_instance_valid(current_tween):
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_QUAD)
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.tween_property(cards_wrapper, "position:y", target_y, 0.18)

func _on_card_pressed(card_data: CardData) -> void:
	card_selected.emit(card_data)

func _on_mouse_entered() -> void:
	show_cards()

func _on_mouse_exited() -> void:
	hide_cards()
