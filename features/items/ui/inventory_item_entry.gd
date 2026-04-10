extends Panel

@onready var icon_rect: TextureRect = $Margin/HBox/Icon
@onready var name_label: Label = $Margin/HBox/Name
@onready var count_label: Label = $Margin/HBox/Count

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

func _ready() -> void:
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.09, 0.1, 0.12, 0.96)
	_normal_style.corner_radius_top_left = 6
	_normal_style.corner_radius_top_right = 6
	_normal_style.corner_radius_bottom_right = 6
	_normal_style.corner_radius_bottom_left = 6
	_normal_style.content_margin_left = 0
	_normal_style.content_margin_top = 0
	_normal_style.content_margin_right = 0
	_normal_style.content_margin_bottom = 0

	_selected_style = _normal_style.duplicate()
	_selected_style.bg_color = Color(0.16, 0.18, 0.22, 1.0)
	_selected_style.border_width_left = 2
	_selected_style.border_width_top = 2
	_selected_style.border_width_right = 2
	_selected_style.border_width_bottom = 2
	_selected_style.border_color = Color(0.82, 0.86, 0.92, 0.95)

	set_selected(false)

func setup(item: Dictionary) -> void:
	var icon_path: String = str(item.get("icon", ""))
	icon_rect.texture = load(icon_path) as Texture2D if icon_path != "" else null
	name_label.text = str(item.get("name", "Item"))
	var count: int = int(item.get("count", 1))
	count_label.text = "x%d" % count

func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)
