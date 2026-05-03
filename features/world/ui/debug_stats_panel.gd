extends PanelContainer

const METRICS := [
	["discipline",   "Disciplina"],
	["felicidad",    "Felicidad"],
	["care_mistakes","Errores"],
	null,
	["confianza",    "Confianza"],
	["estres",       "Estrés"],
	["aburrimiento", "Aburrimiento"],
	["autocontrol",  "Autocontrol"],
]

var _value_labels: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "— TEST —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(header)

	for entry in METRICS:
		if entry == null:
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 2)
			vbox.add_child(sep)
			continue

		var key: String = entry[0]
		var label_text: String = entry[1]

		var row := HBoxContainer.new()
		vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = label_text
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size.x = 32
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		row.add_child(val_lbl)

		_value_labels[key] = val_lbl

	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var ps := GameState.player_save
	if ps == null:
		return
	for key in _value_labels:
		_value_labels[key].text = str(ps.get(key))
