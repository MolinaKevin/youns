class_name ModalFadePanel
extends RefCounted

## Cascarón fade+panel+margin+vbox de los diálogos modales sobre el mundo
## (training_overlay.gd, sleep_overlay.gd): ColorRect de fade + CenterContainer
## + PanelContainer con el mismo estilo + MarginContainer de 20 en los 4 lados
## + VBoxContainer. Cada llamador agrega su contenido al vbox devuelto y
## decide el resto (fundido, visibilidad inicial del panel, botones).

static func build(parent: Node, panel_min_width: float, vbox_separation: float) -> Dictionary:
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fade)

	var centering := CenterContainer.new()
	centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(centering)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = panel_min_width
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	centering.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", vbox_separation)
	margin.add_child(vbox)

	return {"fade": fade, "panel": panel, "vbox": vbox}
