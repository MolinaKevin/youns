extends PanelContainer

const METRICS := [
	["discipline",   "status.discipline"],
	["felicidad",    "status.felicidad"],
	["care_mistakes","status.care_mistakes"],
	null,
	["confianza",    "status.confianza"],
	["estres",       "status.estres"],
	["aburrimiento", "status.aburrimiento"],
	["autocontrol",  "status.autocontrol"],
	["energia",    "status.energia"],
	["salud",        "status.salud"],
	["weight",       "status.weight"],
	null,
	["hambre",       "status.hambre"],
	["ganas_bano",   "status.ganas_bano"],
]

var _value_labels: Dictionary = {}
var _name_labels: Dictionary = {}
var _clock_val: Label
var _states_val: Label
var _anim_youn_val: Label
var _anim_player_val: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "— TEST —"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(header)

	for entry in METRICS:
		if entry == null:
			var sep := HSeparator.new()
			sep.add_theme_constant_override("separation", 2)
			vbox.add_child(sep)
			continue

		var key: String = entry[0]
		var label_text: String = entry[1]

		var row := HBoxContainer.new()
		vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = LocalizationState.t(label_text)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.custom_minimum_size.x = 32
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		row.add_child(val_lbl)

		_value_labels[key] = val_lbl
		_name_labels[key] = [name_lbl, label_text]

	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 2)
	vbox.add_child(sep2)

	var clock_row := HBoxContainer.new()
	vbox.add_child(clock_row)

	var clock_lbl := Label.new()
	clock_lbl.text = LocalizationState.t("debug.time")
	clock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_lbl.add_theme_font_size_override("font_size", 11)
	clock_row.add_child(clock_lbl)
	_name_labels["_time"] = [clock_lbl, "debug.time"]

	_clock_val = Label.new()
	_clock_val.custom_minimum_size.x = 48
	_clock_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_val.add_theme_font_size_override("font_size", 11)
	_clock_val.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	clock_row.add_child(_clock_val)

	var sep3 := HSeparator.new()
	sep3.add_theme_constant_override("separation", 2)
	vbox.add_child(sep3)

	var day_row := HBoxContainer.new()
	vbox.add_child(day_row)

	var day_lbl := Label.new()
	day_lbl.text = LocalizationState.t("debug.day_duration")
	day_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_lbl.add_theme_font_size_override("font_size", 11)
	day_row.add_child(day_lbl)
	_name_labels["_day_duration"] = [day_lbl, "debug.day_duration"]

	var day_val := Label.new()
	day_val.text = "%.1f min" % GameState.DAY_DURATION_MINUTES
	day_val.custom_minimum_size.x = 48
	day_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_val.add_theme_font_size_override("font_size", 11)
	day_val.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	day_row.add_child(day_val)

	var sep4 := HSeparator.new()
	sep4.add_theme_constant_override("separation", 2)
	vbox.add_child(sep4)

	var states_header := Label.new()
	states_header.text = LocalizationState.t("debug.states")
	states_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	states_header.add_theme_font_size_override("font_size", 11)
	states_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(states_header)
	_name_labels["_states_header"] = [states_header, "debug.states"]

	_states_val = Label.new()
	_states_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_states_val.add_theme_font_size_override("font_size", 11)
	_states_val.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0))
	_states_val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_states_val)

	var sep5 := HSeparator.new()
	sep5.add_theme_constant_override("separation", 2)
	vbox.add_child(sep5)

	for pair in [["Youn anim", "_anim_youn"], ["Player", "_anim_player"]]:
		var row := HBoxContainer.new()
		vbox.add_child(row)
		var lbl := Label.new()
		lbl.text = pair[0]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 11)
		val.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		row.add_child(val)
		if pair[1] == "_anim_youn":
			_anim_youn_val = val
		else:
			_anim_player_val = val

	LocalizationState.language_changed.connect(_on_language_changed)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _clock_val:
		_clock_val.text = GameState.get_time_string()
	if _states_val:
		var states := _get_current_states()
		_states_val.text = "\n".join(states) if not states.is_empty() else "-"
	if _anim_youn_val:
		var youn = PartyManager.youn if PartyManager else null
		_anim_youn_val.text = youn.get_current_anim() if is_instance_valid(youn) else "-"
	if _anim_player_val:
		var player = PartyManager.player if PartyManager else null
		if is_instance_valid(player):
			var spd := Vector2(player.velocity.x, player.velocity.z).length()
			_anim_player_val.text = "move" if spd > 0.5 else "idle"
		else:
			_anim_player_val.text = "-"
	var ps := GameState.player_save
	if ps == null:
		return
	for key in _value_labels:
		var val = ps.get(key)
		_value_labels[key].text = "%.1f" % val if val is float else str(val)


func _get_current_states() -> Array[String]:
	var states: Array[String] = []
	var youn_node = PartyManager.youn if PartyManager else null
	if is_instance_valid(youn_node) and youn_node.youn_data != null:
		var data: YounData = youn_node.youn_data
		var hour := GameState.time_of_day_hours
		var in_sleep: bool
		if data.sleep_hour > data.wake_hour:
			in_sleep = hour >= float(data.sleep_hour) or hour < float(data.wake_hour)
		else:
			in_sleep = hour >= float(data.sleep_hour) and hour < float(data.wake_hour)
		if in_sleep:
			states.append(LocalizationState.t("debug.state.sleep"))
	var ps := GameState.player_save
	if ps != null and ps.energia < 20:
		states.append(LocalizationState.t("debug.state.tired"))
	if ps != null and ps.enfermo:
		states.append(LocalizationState.t("debug.state.sick"))
	if ps != null and ps.hambre > 70:
		states.append(LocalizationState.t("debug.state.hungry"))
	if ps != null and ps.needs_bathroom:
		states.append(LocalizationState.t("debug.state.bathroom"))
	return states


func _on_language_changed(_language: String) -> void:
	for key in _name_labels:
		var entry: Array = _name_labels[key]
		entry[0].text = LocalizationState.t(entry[1])
