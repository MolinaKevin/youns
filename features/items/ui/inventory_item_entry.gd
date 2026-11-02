extends Panel

@onready var icon_rect: TextureRect = $Margin/HBox/Icon
@onready var name_label: Label = $Margin/HBox/Name
@onready var count_label: Label = $Margin/HBox/Count

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

func _ready() -> void:
	_normal_style = SelectionChipStyle.normal(Color(0.09, 0.1, 0.12, 0.96), 6, 0.0)
	_selected_style = SelectionChipStyle.selected(Color(0.16, 0.18, 0.22, 1.0), Color(0.82, 0.86, 0.92, 0.95), 6, 2, 0.0)
	set_selected(false)

func setup(item: Dictionary) -> void:
	var icon_path: String = str(item.get("icon", ""))
	icon_rect.texture = UiAssetCache.texture(icon_path)
	var item_id := str(item.get("id", ""))
	name_label.text = LocalizationState.item_name(item_id, str(item.get("name", LocalizationState.t("inventory.item_default"))))
	var count: int = int(item.get("count", 1))
	count_label.text = LocalizationState.t("inventory.count_short", [count])

func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)
