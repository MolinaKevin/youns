class_name SelectionChipStyle
extends RefCounted

## Estilo normal/seleccionado compartido por los ítems de menú con selección
## por teclado/joystick (menu_item.gd, quick_menu.gd): panel oscuro normal,
## borde dorado cuando está seleccionado.

static func normal(bg_color := Color(0.15, 0.15, 0.2, 0.85), corner_radius := 4, content_margin := -1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	_set_corners(style, corner_radius)
	if content_margin >= 0.0:
		_set_content_margin(style, content_margin)
	return style

static func selected(bg_color := Color(0.6, 0.5, 0.1, 0.95), border_color := Color(1.0, 0.85, 0.2),
		corner_radius := 4, border_width := 2, content_margin := -1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	_set_border_width(style, border_width)
	_set_corners(style, corner_radius)
	if content_margin >= 0.0:
		_set_content_margin(style, content_margin)
	return style

static func _set_corners(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

static func _set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_right = width
	style.border_width_top = width
	style.border_width_bottom = width

static func _set_content_margin(style: StyleBoxFlat, margin: float) -> void:
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
