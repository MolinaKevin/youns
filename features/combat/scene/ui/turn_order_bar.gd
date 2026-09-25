extends PanelContainer

## Muestra el orden de la ronda según la iniciativa: una ficha por personaje,
## de izquierda a derecha, con la ficha del que está actuando resaltada.

const BG           := Color(0.03, 0.08, 0.12, 0.9)
const BORDER       := Color(0.35, 0.85, 1.0)
const ACTIVE       := Color(1.0, 0.85, 0.35)
const DONE_ALPHA   := 0.4

var _row: HBoxContainer

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_row)
	visible = false

## entries: [{"name": String, "initiative": int}] ya ordenadas.
## active: índice del que actúa ahora (los anteriores se ven atenuados); -1 = ninguno.
func show_order(entries: Array, active: int) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for i in entries.size():
		if i > 0:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_row.add_child(arrow)
		_row.add_child(_make_chip(entries[i], i == active))
		if active >= 0 and i < active:
			_row.get_child(_row.get_child_count() - 1).modulate.a = DONE_ALPHA
	visible = true

func _make_chip(entry: Dictionary, is_active: bool) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.16, 0.24)
	style.border_color = ACTIVE if is_active else BORDER
	style.set_border_width_all(3 if is_active else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%d  %s" % [entry["initiative"], entry["name"]]
	label.add_theme_font_size_override("font_size", 16)
	if is_active:
		label.add_theme_color_override("font_color", ACTIVE)
	chip.add_child(label)
	return chip
