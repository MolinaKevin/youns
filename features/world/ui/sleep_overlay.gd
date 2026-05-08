extends CanvasLayer

const FADE_DURATION := 1.5

var _fade: ColorRect
var _panel: PanelContainer
var _message: Label
var _yes_btn: Button
var _no_btn: Button
var _showing_not_implemented := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_apply_text()
	LocalizationState.language_changed.connect(_apply_text)
	GameState.set_clock_paused(true)
	_freeze_world()
	_fade_in()


func _build_ui() -> void:
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	var centering := CenterContainer.new()
	centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centering)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.custom_minimum_size.x = 300

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	centering.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 260
	_message.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_message)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	_yes_btn = Button.new()
	_yes_btn.pressed.connect(_on_yes)
	hbox.add_child(_yes_btn)

	_no_btn = Button.new()
	_no_btn.pressed.connect(_on_no)
	hbox.add_child(_no_btn)


func _apply_text(_lang: String = "") -> void:
	if _showing_not_implemented:
		_message.text = LocalizationState.t("sleep.not_implemented")
		_yes_btn.visible = false
		_no_btn.text = LocalizationState.t("sleep.no")
	else:
		_message.text = LocalizationState.t("sleep.save_prompt")
		_yes_btn.visible = true
		_yes_btn.text = LocalizationState.t("sleep.yes")
		_no_btn.text = LocalizationState.t("sleep.no")


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(_show_dialog)


func _show_dialog() -> void:
	_panel.visible = true
	_no_btn.grab_focus()


func _on_yes() -> void:
	_showing_not_implemented = true
	_apply_text()
	_no_btn.grab_focus()


func _on_no() -> void:
	_panel.visible = false
	_skip_time()
	_fade_out()


func _skip_time() -> void:
	var wake_h := 7
	var youn_node = PartyManager.youn if PartyManager else null
	if is_instance_valid(youn_node) and youn_node.youn_data != null:
		wake_h = youn_node.youn_data.wake_hour
	var hours_slept := _calc_hours_slept(GameState.time_of_day_hours, wake_h)
	if GameState.time_of_day_hours >= float(wake_h):
		GameState.current_day += 1
	GameState.time_of_day_hours = float(wake_h)
	GameState.add_energia(_calc_energia_recovery(hours_slept))
	GameState.clock_changed.emit(GameState.time_of_day_hours, GameState.current_day)


func _calc_hours_slept(current_hour: float, wake_h: int) -> int:
	var diff := float(wake_h) - current_hour
	if diff <= 0.0:
		diff += 24.0
	return roundi(diff)


func _calc_energia_recovery(hours: int) -> int:
	if hours >= 7:
		return 100
	# primeras 2h: +8/h; desde la 3ra: +5/h (3 menos por hora adicional)
	return maxi(0, 8 * hours - maxi(0, hours - 2) * 3)


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	tween.tween_callback(_finish)


func _finish() -> void:
	GameState.set_clock_paused(false)
	_unfreeze_world()
	queue_free()


func _freeze_world() -> void:
	var p = PartyManager.player if PartyManager else null
	var y = PartyManager.youn if PartyManager else null
	var c = PartyManager.camera_rig if PartyManager else null
	if is_instance_valid(p): p.set_physics_process(false)
	if is_instance_valid(y): y.set_physics_process(false)
	if is_instance_valid(c): c.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unfreeze_world() -> void:
	var p = PartyManager.player if PartyManager else null
	var y = PartyManager.youn if PartyManager else null
	var c = PartyManager.camera_rig if PartyManager else null
	if is_instance_valid(p): p.set_physics_process(true)
	if is_instance_valid(y): y.set_physics_process(true)
	if is_instance_valid(c): c.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
