extends Control

const MENU_OPTIONS: Array[Dictionary] = [
	{"label_key": "title.menu.new_game", "scene": "res://features/world/game_world/game_world.tscn"},
	{"label_key": "title.menu.quick_battle", "scene": "res://features/combat/scene/combat.tscn"},
	{"label_key": "title.menu.lab", "scene": "res://features/laboratory/scene/laboratory.tscn"},
	{"label_key": "title.menu.deck_builder", "scene": "res://features/deck_builder/ui/deck_builder_screen.tscn"},
	{"label_key": "title.menu.language", "scene": "", "action": "language"},
	{"label_key": "title.menu.exit", "scene": "", "action": "exit"},
]

@onready var options_container: VBoxContainer = $SafeArea/Layout/LeftColumn/MenuPanel/MenuMargin/MenuOptions
@onready var hint_label: Label = $SafeArea/Layout/LeftColumn/Footer/HintLabel
@onready var kick_label: Label = $SafeArea/Layout/LeftColumn/TitleBlock/KickLabel
@onready var subtitle_label: Label = $SafeArea/Layout/LeftColumn/TitleBlock/SubtitleLabel
@onready var status_label: Label = $SafeArea/Layout/RightColumn/HeroPanel/HeroMargin/HeroContent/StatusLabel
@onready var world_name_label: Label = $SafeArea/Layout/RightColumn/HeroPanel/HeroMargin/HeroContent/WorldName
@onready var description_label: Label = $SafeArea/Layout/RightColumn/HeroPanel/HeroMargin/HeroContent/Description
@onready var feature_list_label: Label = $SafeArea/Layout/RightColumn/HeroPanel/HeroMargin/HeroContent/FeatureList
@onready var info_label: Label = $SafeArea/Layout/RightColumn/InfoStrip/InfoLabel
@onready var language_overlay: Control = $LanguageOverlay
@onready var language_title: Label = $LanguageOverlay/Dialog/Margin/VBox/Title
@onready var language_subtitle: Label = $LanguageOverlay/Dialog/Margin/VBox/Subtitle
@onready var spanish_button: Button = $LanguageOverlay/Dialog/Margin/VBox/SpanishButton
@onready var english_button: Button = $LanguageOverlay/Dialog/Margin/VBox/EnglishButton
@onready var current_language_label: Label = $LanguageOverlay/Dialog/Margin/VBox/CurrentLanguageLabel

var _selected_index := 0
var _buttons: Array[Button] = []
var _language_options := ["es", "en"]
var _language_selected_index := 0

func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	spanish_button.pressed.connect(func(): _set_language("es"))
	english_button.pressed.connect(func(): _set_language("en"))
	LocalizationState.language_changed.connect(_apply_localized_text)
	_apply_localized_text()
	_build_menu()
	_update_selection()
	if not LocalizationState.has_saved_language():
		_set_language_overlay_visible(true)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if language_overlay.visible:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_move_language_selection(1)
			return
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_move_language_selection(-1)
			return
		if event.is_action_pressed("ui_accept"):
			_confirm_language_selection()
			return
		if event.is_action_pressed("ui_cancel") and LocalizationState.has_saved_language():
			_set_language_overlay_visible(false)
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
		button.text = LocalizationState.t(option.label_key)
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

	var selected_label: String = LocalizationState.t(MENU_OPTIONS[_selected_index].label_key)
	hint_label.text = LocalizationState.t("title.selected", [selected_label])

func _activate_selected() -> void:
	_on_option_pressed(_selected_index)

func _on_option_pressed(index: int) -> void:
	_selected_index = index
	_update_selection()

	var option: Dictionary = MENU_OPTIONS[index]
	var scene_path: String = option.scene
	var action: String = option.get("action", "")

	if action == "exit":
		get_tree().quit()
		return
	if action == "language":
		_set_language_overlay_visible(true)
		return

	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)

func _apply_localized_text(_language: String = "") -> void:
	kick_label.text = LocalizationState.t("title.prototype")
	subtitle_label.text = LocalizationState.t("title.subtitle")
	status_label.text = LocalizationState.t("title.world_status")
	world_name_label.text = LocalizationState.t("title.world_name")
	description_label.text = LocalizationState.t("title.description")
	feature_list_label.text = LocalizationState.t("title.features")
	info_label.text = LocalizationState.t("title.nav_hint")
	language_title.text = LocalizationState.t("language.title")
	language_subtitle.text = LocalizationState.t("language.subtitle")
	spanish_button.text = LocalizationState.t("language.es")
	english_button.text = LocalizationState.t("language.en")
	current_language_label.text = LocalizationState.t(
		"language.current",
		[LocalizationState.get_language_name()]
	)
	_sync_language_buttons()
	if not _buttons.is_empty():
		for index in _buttons.size():
			_buttons[index].text = LocalizationState.t(MENU_OPTIONS[index].label_key)
	_update_selection()

func _set_language(language: String) -> void:
	LocalizationState.set_language(language)
	_set_language_overlay_visible(false)

func _set_language_overlay_visible(shown: bool) -> void:
	language_overlay.visible = shown
	if visible:
		_language_selected_index = _language_options.find(LocalizationState.current_language)
		if _language_selected_index == -1:
			_language_selected_index = 0
		_sync_language_buttons()

func _move_language_selection(delta: int) -> void:
	_language_selected_index = wrapi(_language_selected_index + delta, 0, _language_options.size())
	_sync_language_buttons()

func _confirm_language_selection() -> void:
	_set_language(_language_options[_language_selected_index])

func _sync_language_buttons() -> void:
	var buttons: Array[Button] = [spanish_button, english_button]
	for index in buttons.size():
		var selected := index == _language_selected_index
		buttons[index].button_pressed = selected
		buttons[index].modulate = Color(1.0, 1.0, 1.0) if selected else Color(0.72, 0.78, 0.8)
