extends GutTest



func test_avanzar_normaliza_el_dia_y_emite_ticks() -> void:
	var clock := GameClock.new()
	clock.set_time(1, 23.5)
	var ticks := [0]
	clock.twenty_min_ticked.connect(func(): ticks[0] += 1)
	clock.advance_hours(1.0)
	assert_eq(clock.current_day, 2)
	assert_almost_eq(clock.time_of_day_hours, 0.5, 0.001)
	assert_eq(ticks[0], 3)


func test_salto_de_sueno_no_emite_ticks() -> void:
	var clock := GameClock.new()
	clock.set_time(1, 22.0)
	var ticks := [0]
	clock.twenty_min_ticked.connect(func(): ticks[0] += 1)
	var slept := clock.skip_to_next_hour(7)
	assert_eq(slept, 9)
	assert_eq(clock.current_day, 2)
	assert_eq(clock.time_of_day_hours, 7.0)
	assert_eq(ticks[0], 0)


func test_pausa_no_avanza_con_tiempo_real() -> void:
	var clock := GameClock.new()
	clock.set_paused(true)
	clock.advance_real_seconds(60.0, 60.0)
	assert_eq(clock.time_of_day_hours, 8.0)
