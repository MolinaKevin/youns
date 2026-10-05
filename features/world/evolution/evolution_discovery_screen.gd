extends CanvasLayer

## Después de la pantalla de evolución: "¡Evolución desbloqueada!" (o "conocida"
## si ya se había llegado antes) y un renglón por condición: las conocidas con
## su texto y las que faltan como "???????". Si esta vez se descubrió una, se
## anuncia arriba; si no, no se dice nada (solo los renglones ocultos).

signal finished

const BG := Color(0.04, 0.09, 0.14, 0.97)
const BORDER := Color(0.35, 0.85, 1.0)
const NEW := Color(1.0, 0.85, 0.35)
const KNOWN := Color(0.9, 0.95, 1.0)
const HIDDEN := Color(0.55, 0.6, 0.65)
## Renglón de una condición sin descubrir.
const HIDDEN_TEXT := "???????"

var _result: Dictionary

func setup(result: Dictionary) -> void:
	_result = result

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()

func _build() -> void:
	var to: YounData = _result.get("to")
	var discovery: Dictionary = _result.get("discovery", {})

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var first_time: bool = discovery.get("first_time", true)
	column.add_child(_label(LocalizationState.t(
		"evolution.unlocked.title" if first_time else "evolution.known.title"), 26, NEW, true))
	if to != null:
		column.add_child(_label("%s · %s" % [to.youn_name, LocalizationState.youn_stage_name(to.stage)], 20, KNOWN, true))
	column.add_child(HSeparator.new())

	if to == null or to.evolution_conditions.is_empty():
		var key := "evolution.wildcard" if to != null and to.is_wildcard else "evolution.no_conditions"
		column.add_child(_label(LocalizationState.t(key), 16, KNOWN))
	else:
		var conditions := to.evolution_conditions
		var revealed: int = discovery.get("revealed", -1)
		var known: Array = discovery.get("known", [])
		# Si no se descubrió nada, no se dice nada: solo los renglones ocultos.
		if revealed >= 0:
			var header := "evolution.condition.new" if discovery.get("revealed_met", false) else "evolution.condition.new_unmet"
			column.add_child(_label(LocalizationState.t(header), 16, KNOWN))
			column.add_child(_label("★ " + conditions[revealed].describe(), 18, NEW))
			column.add_child(HSeparator.new())
		for i in conditions.size():
			if known.has(i):
				column.add_child(_label("• " + conditions[i].describe(), 16, NEW if i == revealed else KNOWN))
			else:
				column.add_child(_label("• " + HIDDEN_TEXT, 16, HIDDEN))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	var ok := Button.new()
	ok.text = LocalizationState.t("evolution.continue")
	ok.custom_minimum_size = Vector2(180, 44)
	ok.pressed.connect(_on_continue)
	footer.add_child(ok)

func _label(text: String, size: int, color: Color, centered := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _on_continue() -> void:
	finished.emit()
	queue_free()
