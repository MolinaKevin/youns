extends CanvasLayer

const ITEM_SIZE := Vector2(88, 88)
const ICON_SIZE := 30

const ITEMS := {
	"up":    {key = "quick_menu.reward", icon = "res://assets/icons/icon_1.png"},
	"right": {key = "quick_menu.play",   icon = "res://assets/icons/icon_2.png"},
	"left":  {key = "quick_menu.deny",   icon = "res://assets/icons/icon_3.png"},
	"down":  {key = "quick_menu.punish", icon = "res://assets/icons/icon_4.png"},
}

@onready var cross: GridContainer = $Center/Cross

var _panels: Dictionary = {}
var _labels: Dictionary = {}
var _selected := "up"
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_build_cross()
	LocalizationState.language_changed.connect(_apply_localized_text)
	hide()


func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		_style_normal.set("corner_radius_" + corner, 4)

	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.6, 0.5, 0.1, 0.95)
	_style_selected.border_color = Color(1.0, 0.85, 0.2)
	for side in ["left", "right", "top", "bottom"]:
		_style_selected.set("border_width_" + side, 2)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		_style_selected.set("corner_radius_" + corner, 4)


func _build_cross() -> void:
	var layout := [
		["",     "up",   ""     ],
		["left", "",     "right"],
		["",     "down", ""     ],
	]
	for row in layout:
		for dir in row:
			if dir == "":
				var spacer := Control.new()
				spacer.custom_minimum_size = ITEM_SIZE
				cross.add_child(spacer)
			else:
				var panel := _make_panel(dir)
				cross.add_child(panel)
				_panels[dir] = panel
	_apply_localized_text()
	_refresh_selection()


func _make_panel(dir: String) -> PanelContainer:
	var data: Dictionary = ITEMS[dir]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = ITEM_SIZE
	panel.add_theme_stylebox_override("panel", _style_normal)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = load(data.icon) as Texture2D
	vbox.add_child(icon_rect)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(label)
	_labels[dir] = label

	return panel


func _apply_localized_text(_language: String = "") -> void:
	for dir in _labels:
		_labels[dir].text = LocalizationState.t(ITEMS[dir].key)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_G and event.pressed and not event.echo:
		if visible:
			close()
		else:
			open()
		return

	if not visible:
		return

	if event.is_action_pressed("ui_up"):
		_selected = "up"
	elif event.is_action_pressed("ui_down"):
		_selected = "down"
	elif event.is_action_pressed("ui_left"):
		_selected = "left"
	elif event.is_action_pressed("ui_right"):
		_selected = "right"
	elif event.is_action_pressed("ui_accept"):
		_activate()
		return
	elif event.is_action_pressed("ui_cancel"):
		close()
		return
	_refresh_selection()


func _refresh_selection() -> void:
	for dir in _panels:
		var panel: PanelContainer = _panels[dir]
		var is_sel: bool = dir == _selected
		panel.add_theme_stylebox_override("panel", _style_selected if is_sel else _style_normal)
		panel.modulate = Color.WHITE if is_sel else Color(0.65, 0.65, 0.65, 1.0)


func open() -> void:
	_selected = "up"
	_refresh_selection()
	show()
	GameState.set_clock_paused(true)
	get_tree().paused = true


func close() -> void:
	GameState.set_clock_paused(false)
	hide()
	get_tree().paused = false


func _activate() -> void:
	match _selected:
		"up":   _cmd_premiar()
		"down": _cmd_castigar()
		"left": _cmd_negar()
		"right": _cmd_jugar()
	close()


func _cmd_premiar() -> void:
	GameState.add_discipline(-1)
	GameState.add_felicidad(+3)
	GameState.add_confianza(+2)
	GameState.add_estres(-1)
	GameState.add_aburrimiento(-1)
	GameState.add_autocontrol(-1)


func _cmd_castigar() -> void:
	GameState.add_felicidad(-4)
	GameState.add_confianza(-3)
	GameState.add_estres(+4)
	GameState.add_autocontrol(-1)


func _cmd_negar() -> void:
	GameState.add_felicidad(-2)
	GameState.add_confianza(-1)
	GameState.add_estres(+1)
	GameState.add_autocontrol(+1)


func _cmd_jugar() -> void:
	GameState.add_felicidad(+2)
	GameState.add_confianza(+2)
	GameState.add_estres(-2)
	GameState.add_aburrimiento(-4)
