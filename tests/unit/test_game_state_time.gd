extends GutTest

# GameState es un autoload — está disponible globalmente en los tests


func before_each() -> void:
	GameState.current_day = 1
	GameState.time_of_day_hours = 8.0


# ── get_time_string ───────────────────────────────────────────────────────────

func test_time_string_format_morning() -> void:
	GameState.time_of_day_hours = 8.0
	assert_eq(GameState.get_time_string(), "08:00")


func test_time_string_format_noon() -> void:
	GameState.time_of_day_hours = 12.5
	assert_eq(GameState.get_time_string(), "12:30")


func test_time_string_pads_midnight() -> void:
	GameState.time_of_day_hours = 0.0
	assert_eq(GameState.get_time_string(), "00:00")


func test_time_string_late_night() -> void:
	GameState.time_of_day_hours = 23.99
	assert_eq(GameState.get_time_string(), "23:59")


# ── get_time_ratio ────────────────────────────────────────────────────────────

func test_time_ratio_at_midnight() -> void:
	GameState.time_of_day_hours = 0.0
	assert_eq(GameState.get_time_ratio(), 0.0)


func test_time_ratio_at_noon() -> void:
	GameState.time_of_day_hours = 12.0
	assert_almost_eq(GameState.get_time_ratio(), 0.5, 0.001)


func test_time_ratio_at_end_of_day() -> void:
	GameState.time_of_day_hours = 24.0
	assert_almost_eq(GameState.get_time_ratio(), 1.0, 0.001)


# ── get_total_hours ───────────────────────────────────────────────────────────

func test_total_hours_day_1_at_8am() -> void:
	GameState.current_day = 1
	GameState.time_of_day_hours = 8.0
	assert_eq(GameState.get_total_hours(), 32.0)  # 1*24 + 8


func test_total_hours_day_2_at_midnight() -> void:
	GameState.current_day = 2
	GameState.time_of_day_hours = 0.0
	assert_eq(GameState.get_total_hours(), 48.0)  # 2*24 + 0


func test_total_hours_increases_with_day() -> void:
	GameState.current_day = 1
	GameState.time_of_day_hours = 0.0
	var day1 := GameState.get_total_hours()
	GameState.current_day = 2
	var day2 := GameState.get_total_hours()
	assert_eq(day2 - day1, 24.0)
