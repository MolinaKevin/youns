extends Control

const MENU_OPTIONS: Array[Dictionary] = [
	{"label": "Nueva partida", "scene": "res://features/world/game_world/game_world.tscn"},
	{"label": "Combate rapido", "scene": "res://features/combat/scene/combat.tscn"},
	{"label": "Laboratorio", "scene": "res://features/laboratory/scene/laboratory.tscn"},
	{"label": "Constructor de mazo", "scene": "res://features/deck_builder/ui/deck_builder_screen.tscn"},
	{"label": "Salir", "scene": ""},
]

@onready var options_container: VBoxContainer = $SafeArea/Layout/LeftColumn/MenuPanel/MenuMargin/MenuOptions
@onready var hint_label: Label = $SafeArea/Layout/LeftColumn/Footer/HintLabel

var _selected_index := 0
var _buttons: Array[Button] = []

func _ready() -> void:
	GameState.set_clock_visible(false)
	GameState.set_clock_paused(true)
	GameState.set_youns_status_visible(false)
	_build_menu()
	_update_selection()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_accept"):
		_activate_selected()

func _build_menu() -> void:
	for child in options_container.get_children():
		child.queue_free()
	_buttons.clear()

	for option: Dictionary in MENU_OPTIONS:
		var button := Button.new()
		button.text = option.label
		button.custom_minimum_size = Vector2(0, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_option_pressed.bind(_buttons.size()))
		_style_button(button)
		options_container.add_child(button)
		_buttons.append(button)

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 22)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.11, 0.14, 0.88)
	normal.border_color = Color(0.33, 0.52, 0.58, 0.9)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_right = 8
	normal.corner_radius_bottom_left = 8
	normal.content_margin_left = 18
	normal.content_margin_top = 10
	normal.content_margin_right = 18
	normal.content_margin_bottom = 10

	var hover := normal.duplicate()
	hover.bg_color = Color(0.14, 0.2, 0.23, 0.94)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.22, 0.31, 0.28, 0.98)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.06, 0.08, 0.1, 0.65)
	disabled.border_color = Color(0.2, 0.24, 0.28, 0.7)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)

func _move_selection(delta: int) -> void:
	_selected_index = wrapi(_selected_index + delta, 0, _buttons.size())
	_update_selection()

func _update_selection() -> void:
	for index in _buttons.size():
		var button := _buttons[index]
		var is_selected := index == _selected_index
		button.modulate = Color(1.0, 1.0, 1.0) if is_selected else Color(0.72, 0.78, 0.8)

	var selected_label: String = MENU_OPTIONS[_selected_index].label
	hint_label.text = "Seleccionado: %s" % selected_label

func _activate_selected() -> void:
	_on_option_pressed(_selected_index)

func _on_option_pressed(index: int) -> void:
	_selected_index = index
	_update_selection()

	var option: Dictionary = MENU_OPTIONS[index]
	var scene_path: String = option.scene

	if option.label == "Salir":
		get_tree().quit()
		return

	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)
