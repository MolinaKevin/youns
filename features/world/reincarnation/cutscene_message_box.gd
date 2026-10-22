class_name CutsceneMessageBox
extends RefCounted

## Caja de mensaje modal con "Continuar" (y el panel genérico que la
## contiene), reusable por cualquier pantalla de una cutscene. `host` es el
## Node dueño exclusivo de esta instancia — necesita `_ui` (el CanvasLayer
## donde se agregan los paneles) y `_flash` (el ColorRect de fundido, que
## debe quedar siempre al frente).

const PANEL_BG := Color(0.04, 0.09, 0.14, 0.97)
const BORDER := Color(0.35, 0.85, 1.0)

var host

func _init(p_host) -> void:
	host = p_host

func panel(min_width: float) -> Array:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	host._ui.add_child(root)
	host._ui.move_child(host._flash, -1)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(min_width, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", style)
	center.add_child(p)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	p.add_child(column)
	return [root, column]

func label(text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	return l

## Un mensaje con "Continuar" (y opcionalmente algo debajo del texto).
func message(text: String, extra: Control = null) -> void:
	var parts := panel(460)
	var column: VBoxContainer = parts[1]
	column.add_child(label(text))
	if extra != null:
		column.add_child(extra)
	var ok := Button.new()
	ok.text = LocalizationState.t("reincarnation.continue")
	ok.custom_minimum_size = Vector2(0, 44)
	column.add_child(ok)
	ok.grab_focus()
	await ok.pressed
	parts[0].queue_free()

## Fila de corazones: llenos los que quedan, apagados los perdidos.
func hearts(filled: int, total: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in total:
		var heart := Heart.new()
		heart.filled = i < filled
		row.add_child(heart)
	return row

## Un corazón dibujado (la fuente no tiene ♥).
class Heart extends Control:
	var filled := true
	func _init() -> void:
		custom_minimum_size = Vector2(34, 30)
	func _draw() -> void:
		var color := Color(0.9, 0.2, 0.3) if filled else Color(0.3, 0.3, 0.35)
		var r := 8.5
		draw_circle(Vector2(8.5, 9), r, color)
		draw_circle(Vector2(25.5, 9), r, color)
		draw_colored_polygon(PackedVector2Array([Vector2(0.6, 11), Vector2(33.4, 11), Vector2(17, 29)]), color)
