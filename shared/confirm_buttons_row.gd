class_name ConfirmButtonsRow
extends RefCounted

## Fila "Sí"/"No" centrada, compartida por los diálogos de confirmación de
## guardado (sleep_overlay.gd, save_station.gd). Cada llamador sigue
## poniendo el texto de los botones (algunos lo re-aplican en
## language_changed) y el resto del panel a su gusto.

static func build(parent: Control, on_yes: Callable, on_no: Callable) -> Dictionary:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)
	var yes := Button.new()
	yes.pressed.connect(on_yes)
	hbox.add_child(yes)
	var no := Button.new()
	no.pressed.connect(on_no)
	hbox.add_child(no)
	return {"yes": yes, "no": no}
