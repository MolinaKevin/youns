extends Control

## Pantalla de fin de lucha (placeholder), para victoria o derrota: título,
## subtítulo, ganancia de stats y oro, y un botón para continuar. Tapa todo el
## combate mientras está visible.

signal continue_pressed

const BG     := Color(0.03, 0.08, 0.12, 0.96)
const BORDER := Color(0.35, 0.85, 1.0)
const GAIN   := Color(0.55, 1.0, 0.6)
const DEFEAT_BORDER := Color(0.85, 0.25, 0.25)

var _title: Label
var _subtitle: Label
var _stats_grid: GridContainer
var _gold_label: Label
var _continue_button: Button
var _panel_style: StyleBoxFlat

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Por encima de las cartas de la mano, que usan z_index hasta 200 al hacer hover.
	z_index = 1000
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = BG
	_panel_style.border_color = BORDER
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(10)
	_panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	column.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 18)
	column.add_child(_subtitle)

	column.add_child(HSeparator.new())

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_stats_grid.add_theme_constant_override("h_separation", 40)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	_stats_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_stats_grid)

	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_gold_label)

	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(0, 48)
	_continue_button.add_theme_font_size_override("font_size", 18)
	_continue_button.pressed.connect(func(): continue_pressed.emit())
	column.add_child(_continue_button)

## stat_gains: [[nombre, cantidad], ...]
func show_victory(stat_gains: Array, gold: int) -> void:
	_show(LocalizationState.t("combat.victory.title"), LocalizationState.t("combat.victory.subtitle"),
		BORDER, stat_gains, gold)

func show_defeat() -> void:
	_show(LocalizationState.t("combat.defeat.title"), LocalizationState.t("combat.defeat.subtitle"),
		DEFEAT_BORDER, [], 0)

func _show(title: String, subtitle: String, border: Color, stat_gains: Array, gold: int) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_panel_style.border_color = border
	_continue_button.text = LocalizationState.t("combat.victory.continue")
	_stats_grid.visible = not stat_gains.is_empty()
	for child in _stats_grid.get_children():
		_stats_grid.remove_child(child)
		child.queue_free()
	for gain in stat_gains:
		var name_label := Label.new()
		name_label.text = str(gain[0])
		name_label.add_theme_font_size_override("font_size", 18)
		_stats_grid.add_child(name_label)
		var value_label := Label.new()
		value_label.text = "+%d" % int(gain[1])
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", GAIN)
		_stats_grid.add_child(value_label)
	_gold_label.text = LocalizationState.t("combat.victory.gold", [gold])
	_gold_label.visible = gold > 0
	visible = true
	_continue_button.grab_focus()
