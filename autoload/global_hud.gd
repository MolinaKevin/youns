extends Node

signal clock_visibility_changed(visible: bool)
signal clock_pause_changed(paused: bool)
signal clock_style_changed(style: int)
signal youns_status_changed(discipline: int, care_mistakes: int)
signal youns_status_visibility_changed(visible: bool)

const DAY_CLOCK_SCENE: PackedScene = preload("res://features/world/ui/day_clock.tscn")
const YOUNS_STATUS_SCENE: PackedScene = preload("res://features/world/ui/youns_status_panel.tscn")
const DEBUG_STATS_SCRIPT: GDScript = preload("res://features/world/ui/debug_stats_panel.gd")

var clock_visible := true
var clock_style := 0
var youns_status_visible := false

var _day_clock_ui: CanvasLayer
var _youns_status_ui: CanvasLayer
var _debug_stats_ui: CanvasLayer
var _toast_ui: CanvasLayer
var _toast_label: Label
var _toast_tween: Tween

func _ready() -> void:
	_ensure_day_clock_ui()
	_ensure_youns_status_ui()
	if GameState.test_mode:
		_ensure_debug_stats_ui()
	clock_visibility_changed.emit(clock_visible)
	clock_pause_changed.emit(GameState.clock_paused)
	notify_youns_status_changed()
	youns_status_visibility_changed.emit(youns_status_visible)

func set_clock_visible(visible: bool) -> void:
	clock_visible = visible
	if is_instance_valid(_day_clock_ui):
		_day_clock_ui.visible = visible
	clock_visibility_changed.emit(visible)

func set_clock_paused(paused: bool) -> void:
	GameState.clock_paused = paused
	clock_pause_changed.emit(paused)

func set_clock_style(style: int) -> void:
	clock_style = style
	clock_style_changed.emit(style)

func set_youns_status_visible(visible: bool) -> void:
	youns_status_visible = visible
	if is_instance_valid(_youns_status_ui):
		_youns_status_ui.visible = visible
	youns_status_visibility_changed.emit(visible)

func has_persistent_clock_ui() -> bool:
	return GameState.test_mode or (GameState.player_save != null and GameState.player_save.clock_ui_unlocked)

func has_persistent_care_ui() -> bool:
	return GameState.player_save != null and GameState.player_save.care_ui_unlocked

func sync_overworld_ui_visibility() -> void:
	set_clock_visible(has_persistent_clock_ui())
	set_youns_status_visible(has_persistent_care_ui())

func notify_youns_status_changed() -> void:
	if GameState.player_save == null:
		return
	youns_status_changed.emit(GameState.player_save.discipline, GameState.player_save.care_mistakes)

func _ensure_day_clock_ui() -> void:
	if is_instance_valid(_day_clock_ui):
		return
	_day_clock_ui = CanvasLayer.new()
	_day_clock_ui.name = "GlobalDayClock"
	_day_clock_ui.layer = 50
	_day_clock_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	var clock := DAY_CLOCK_SCENE.instantiate()
	clock.offset_left = 16.0
	clock.offset_top = 16.0
	clock.offset_right = 126.0
	clock.offset_bottom = 126.0
	_day_clock_ui.add_child(clock)
	get_tree().root.call_deferred("add_child", _day_clock_ui)

func _ensure_youns_status_ui() -> void:
	if is_instance_valid(_youns_status_ui):
		return
	_youns_status_ui = CanvasLayer.new()
	_youns_status_ui.name = "GlobalYounsStatus"
	_youns_status_ui.layer = 45
	_youns_status_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_youns_status_ui.visible = youns_status_visible

	var panel: Control = YOUNS_STATUS_SCENE.instantiate()
	panel.offset_left = 16.0
	panel.offset_top = 714.0
	panel.offset_right = 292.0
	panel.offset_bottom = 884.0
	_youns_status_ui.add_child(panel)
	get_tree().root.call_deferred("add_child", _youns_status_ui)

func show_toast(text: String, duration: float = 2.5) -> void:
	_ensure_toast_ui()
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_ui.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = get_tree().create_tween()
	_toast_tween.tween_interval(duration - 0.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func(): _toast_ui.visible = false)

func _ensure_toast_ui() -> void:
	if is_instance_valid(_toast_ui):
		return
	_toast_ui = CanvasLayer.new()
	_toast_ui.name = "GlobalToast"
	_toast_ui.layer = 90
	_toast_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_ui.visible = false

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.anchor_left = 0.0
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_right = 1.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.offset_top = -120.0
	_toast_label.offset_bottom = -60.0
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_toast_ui.add_child(_toast_label)
	get_tree().root.call_deferred("add_child", _toast_ui)

func set_debug_stats_visible(visible: bool) -> void:
	if is_instance_valid(_debug_stats_ui):
		_debug_stats_ui.visible = visible

func _ensure_debug_stats_ui() -> void:
	if is_instance_valid(_debug_stats_ui):
		return
	_debug_stats_ui = CanvasLayer.new()
	_debug_stats_ui.name = "GlobalDebugStats"
	_debug_stats_ui.layer = 80
	_debug_stats_ui.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.set_script(DEBUG_STATS_SCRIPT)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -196.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = 246.0
	_debug_stats_ui.add_child(panel)
	get_tree().root.call_deferred("add_child", _debug_stats_ui)
