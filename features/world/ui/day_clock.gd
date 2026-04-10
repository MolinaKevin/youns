extends Panel

@onready var time_label: Label = $Margin/VBox/TimeLabel
@onready var day_label: Label = $Margin/VBox/DayLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = GameState.clock_visible
	_refresh_clock(GameState.time_of_day_hours, GameState.current_day)
	GameState.clock_changed.connect(_refresh_clock)
	GameState.clock_visibility_changed.connect(_on_clock_visibility_changed)

func _exit_tree() -> void:
	if GameState.clock_changed.is_connected(_refresh_clock):
		GameState.clock_changed.disconnect(_refresh_clock)
	if GameState.clock_visibility_changed.is_connected(_on_clock_visibility_changed):
		GameState.clock_visibility_changed.disconnect(_on_clock_visibility_changed)

func _draw() -> void:
	var clock_center: Vector2 = Vector2(size.x * 0.5, 56.0)
	var radius: float = minf(size.x * 0.32, 42.0)

	draw_circle(clock_center, radius + 7.0, Color(0.06, 0.11, 0.16, 0.92))
	draw_circle(clock_center, radius, Color(0.83, 0.8, 0.66, 0.95))
	draw_arc(clock_center, radius, 0.0, TAU, 64, Color(0.23, 0.2, 0.14), 3.0)

	for hour in range(24):
		var angle: float = TAU * (float(hour) / 24.0) - PI * 0.5
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var outer: Vector2 = clock_center + direction * radius
		var inner: Vector2 = clock_center + direction * (radius - (10.0 if hour % 6 == 0 else 6.0))
		draw_line(inner, outer, Color(0.23, 0.2, 0.14), 2.0)

	var hand_angle: float = TAU * GameState.get_time_ratio() - PI * 0.5
	var hand_end: Vector2 = clock_center + Vector2(cos(hand_angle), sin(hand_angle)) * (radius - 12.0)
	draw_line(clock_center, hand_end, Color(0.72, 0.18, 0.13), 3.0)
	draw_circle(clock_center, 4.5, Color(0.2, 0.08, 0.07))

func _refresh_clock(_current_hour: float, current_day: int) -> void:
	time_label.text = GameState.get_time_string()
	day_label.text = "Dia %d" % current_day
	queue_redraw()

func _on_clock_visibility_changed(clock_is_visible: bool) -> void:
	visible = clock_is_visible
