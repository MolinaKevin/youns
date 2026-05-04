extends PanelContainer

@onready var icon_rect: TextureRect = $VBox/Icon
@onready var name_label: Label = $VBox/NameLabel

var _selected_style: StyleBoxFlat
var _normal_style: StyleBoxFlat
var _disabled := false

func _ready() -> void:
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	_normal_style.corner_radius_top_left = 4
	_normal_style.corner_radius_top_right = 4
	_normal_style.corner_radius_bottom_left = 4
	_normal_style.corner_radius_bottom_right = 4

	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(0.6, 0.5, 0.1, 0.95)
	_selected_style.border_width_left = 2
	_selected_style.border_width_right = 2
	_selected_style.border_width_top = 2
	_selected_style.border_width_bottom = 2
	_selected_style.border_color = Color(1.0, 0.85, 0.2)
	_selected_style.corner_radius_top_left = 4
	_selected_style.corner_radius_top_right = 4
	_selected_style.corner_radius_bottom_left = 4
	_selected_style.corner_radius_bottom_right = 4

	add_theme_stylebox_override("panel", _normal_style)

func setup(item_name: String, texture: Texture2D) -> void:
	name_label.text = item_name
	if texture:
		icon_rect.texture = texture

func set_disabled(disabled: bool) -> void:
	_disabled = disabled
	modulate = Color(0.4, 0.4, 0.45, 0.7) if _disabled else Color(0.65, 0.65, 0.65, 1.0)

func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)
	if _disabled:
		modulate = Color.WHITE if selected else Color(0.4, 0.4, 0.45, 0.7)
	else:
		modulate = Color.WHITE if selected else Color(0.65, 0.65, 0.65, 1.0)
