extends Panel

const MAX_DISCIPLINE := 100.0
const MAX_CARE_MISTAKES := 10.0

@onready var header_label: Label = $Margin/VBox/Header
@onready var discipline_name: Label = $Margin/VBox/DisciplineRow/Top/Name
@onready var discipline_value: Label = $Margin/VBox/DisciplineRow/Top/Value
@onready var discipline_bar: ColorRect = $Margin/VBox/DisciplineRow/BarFrame/BarFill
@onready var care_name: Label = $Margin/VBox/CareRow/Top/Name
@onready var care_value: Label = $Margin/VBox/CareRow/Top/Value
@onready var care_bar: ColorRect = $Margin/VBox/CareRow/BarFrame/BarFill

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = GameState.youns_status_visible
	LocalizationState.language_changed.connect(_apply_localized_text)
	GameState.youns_status_changed.connect(_refresh_status)
	GameState.youns_status_visibility_changed.connect(_on_visibility_changed)
	_apply_localized_text()
	_refresh_status(GameState.player_save.discipline, GameState.player_save.care_mistakes)

func _exit_tree() -> void:
	if GameState.youns_status_changed.is_connected(_refresh_status):
		GameState.youns_status_changed.disconnect(_refresh_status)
	if GameState.youns_status_visibility_changed.is_connected(_on_visibility_changed):
		GameState.youns_status_visibility_changed.disconnect(_on_visibility_changed)

func _refresh_status(discipline: int, care_mistakes: int) -> void:
	discipline_value.text = "%d%%" % discipline
	care_value.text = "%d" % care_mistakes
	_set_fill_width(discipline_bar, float(discipline) / MAX_DISCIPLINE)
	_set_fill_width(care_bar, float(care_mistakes) / MAX_CARE_MISTAKES)

func _set_fill_width(fill: Control, ratio: float) -> void:
	var frame_width := maxf((fill.get_parent() as Control).size.x, 240.0)
	fill.size.x = maxf(8.0, frame_width * clampf(ratio, 0.0, 1.0))

func _on_visibility_changed(panel_is_visible: bool) -> void:
	visible = panel_is_visible

func _apply_localized_text(_language: String = "") -> void:
	header_label.text = LocalizationState.t("status.title")
	discipline_name.text = LocalizationState.t("status.discipline")
	care_name.text = LocalizationState.t("status.care_mistakes")
