extends Panel

const PERIODS := [
	{"name": "Mañana", "start_h": 4.0,  "end_h": 8.0,  "color": Color(1.00, 0.82, 0.32, 0.92)},
	{"name": "Día",    "start_h": 8.0,  "end_h": 16.0, "color": Color(0.36, 0.62, 1.00, 0.92)},
	{"name": "Tarde",  "start_h": 16.0, "end_h": 20.0, "color": Color(1.00, 0.44, 0.14, 0.92)},
	{"name": "Noche",  "start_h": 20.0, "end_h": 28.0, "color": Color(0.07, 0.07, 0.22, 0.96)},
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = GameState.clock_visible
	LocalizationState.language_changed.connect(_refresh_language)
	_refresh_clock(GameState.time_of_day_hours, GameState.current_day)
	GameState.clock_changed.connect(_refresh_clock)
	GameState.clock_visibility_changed.connect(_on_clock_visibility_changed)
	GameState.clock_style_changed.connect(_on_style_changed)

func _exit_tree() -> void:
	if GameState.clock_changed.is_connected(_refresh_clock):
		GameState.clock_changed.disconnect(_refresh_clock)
	if GameState.clock_visibility_changed.is_connected(_on_clock_visibility_changed):
		GameState.clock_visibility_changed.disconnect(_on_clock_visibility_changed)
	if GameState.clock_style_changed.is_connected(_on_style_changed):
		GameState.clock_style_changed.disconnect(_on_style_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.test_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			GameState.set_clock_style((GameState.clock_style + 1) % 2)

func _on_style_changed(_style: int) -> void:
	_refresh_clock(GameState.time_of_day_hours, GameState.current_day)

func _draw() -> void:
	var clock_center := Vector2(size.x * 0.5, size.y * 0.5)
	var radius := minf(size.x, size.y) * 0.36
	if GameState.clock_style == 0:
		_draw_analog(clock_center, radius)
	else:
		_draw_sectors(clock_center, radius)

func _draw_analog(clock_center: Vector2, radius: float) -> void:
	draw_circle(clock_center, radius + 7.0, Color(0.06, 0.11, 0.16, 0.92))
	draw_circle(clock_center, radius, Color(0.83, 0.8, 0.66, 0.95))
	draw_arc(clock_center, radius, 0.0, TAU, 64, Color(0.23, 0.2, 0.14), 3.0)

	for hour in range(24):
		var angle := TAU * (float(hour) / 24.0) - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var outer := clock_center + direction * radius
		var inner := clock_center + direction * (radius - (10.0 if hour % 4 == 0 else 5.0))
		draw_line(inner, outer, Color(0.23, 0.2, 0.14), 2.0)

	var hand_angle := TAU * GameState.get_time_ratio() - PI * 0.5
	var hand_end := clock_center + Vector2(cos(hand_angle), sin(hand_angle)) * (radius - 12.0)
	draw_line(clock_center, hand_end, Color(0.72, 0.18, 0.13), 3.0)
	draw_circle(clock_center, 4.5, Color(0.2, 0.08, 0.07))

func _draw_sectors(clock_center: Vector2, radius: float) -> void:
	draw_circle(clock_center, radius + 7.0, Color(0.06, 0.11, 0.16, 0.92))

	for p in PERIODS:
		var sa: float = TAU * (p["start_h"] as float) / 24.0 - PI * 0.5
		var ea: float = TAU * (p["end_h"] as float) / 24.0 - PI * 0.5
		draw_colored_polygon(_sector_polygon(clock_center, radius, sa, ea), p["color"])

	draw_arc(clock_center, radius, 0.0, TAU, 64, Color(0.06, 0.11, 0.16, 0.8), 2.0)

	for p in PERIODS:
		var a: float = TAU * (p["start_h"] as float) / 24.0 - PI * 0.5
		draw_line(clock_center, clock_center + Vector2(cos(a), sin(a)) * (radius + 7.0), Color(0.06, 0.11, 0.16, 0.9), 2.0)

	var hand_angle := TAU * GameState.get_time_ratio() - PI * 0.5
	var hand_end := clock_center + Vector2(cos(hand_angle), sin(hand_angle)) * (radius - 6.0)
	draw_line(clock_center, hand_end, Color(1.0, 1.0, 1.0, 0.95), 2.5)
	draw_circle(clock_center, 3.5, Color(1.0, 1.0, 1.0, 0.95))

func _sector_polygon(center: Vector2, radius: float, start_a: float, end_a: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(center)
	for i in range(33):
		var a := start_a + (end_a - start_a) * float(i) / 32.0
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

func _get_current_period() -> Dictionary:
	var h := GameState.time_of_day_hours
	if h >= 4.0 and h < 8.0:
		return PERIODS[0]  # Mañana
	elif h >= 8.0 and h < 16.0:
		return PERIODS[1]  # Día
	elif h >= 16.0 and h < 20.0:
		return PERIODS[2]  # Tarde
	else:
		return PERIODS[3]  # Noche (20-24 y 0-4)

func _refresh_clock(_current_hour: float, _current_day: int) -> void:
	queue_redraw()

func _on_clock_visibility_changed(clock_is_visible: bool) -> void:
	visible = clock_is_visible

func _refresh_language(_language: String = "") -> void:
	_refresh_clock(GameState.time_of_day_hours, GameState.current_day)
