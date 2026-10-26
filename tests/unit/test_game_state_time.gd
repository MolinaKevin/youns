extends GutTest

# GameState es un autoload — está disponible globalmente en los tests

var _previous_day := 1
var _previous_time_of_day_hours := 8.0
var _previous_clock_paused := false
var _previous_save: PlayerSaveData

func before_each() -> void:
	_previous_day = GameState.current_day
	_previous_time_of_day_hours = GameState.time_of_day_hours
	_previous_clock_paused = GameState.clock_paused
	_previous_save = GameState.player_save
	GameState.current_day = 1
	GameState.time_of_day_hours = 8.0


func after_each() -> void:
	GameState.current_day = _previous_day
	GameState.time_of_day_hours = _previous_time_of_day_hours
	GameState.clock_paused = _previous_clock_paused
	GameState.player_save = _previous_save


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


# ── discard_pending_ticks (dormir) ────────────────────────────────────────────

func test_discard_pending_ticks_no_emite_los_ticks_salteados() -> void:
	var was_paused := GameState.clock_paused
	var save_backup := GameState.player_save
	GameState.player_save = null  # los ticks no tocan ninguna partida
	GameState.clock_paused = false
	GameState.discard_pending_ticks()
	var ticks := [0]
	var count := func() -> void: ticks[0] += 1
	GameState.twenty_min_ticked.connect(count)
	GameState.time_of_day_hours = 17.0  # 9 h de salto
	GameState.discard_pending_ticks()
	GameState.advance_real_seconds(0.0)
	GameState.twenty_min_ticked.disconnect(count)
	GameState.clock_paused = was_paused
	GameState.player_save = save_backup
	assert_eq(ticks[0], 0)


func test_sin_discard_los_ticks_salteados_se_emiten() -> void:
	var was_paused := GameState.clock_paused
	var save_backup := GameState.player_save
	GameState.player_save = null  # los ticks no tocan ninguna partida
	GameState.clock_paused = false
	GameState.discard_pending_ticks()
	var ticks := [0]
	var count := func() -> void: ticks[0] += 1
	GameState.twenty_min_ticked.connect(count)
	GameState.time_of_day_hours = 9.0  # 1 h de salto: 3 ticks
	GameState.advance_real_seconds(0.0)
	GameState.twenty_min_ticked.disconnect(count)
	GameState.clock_paused = was_paused
	GameState.player_save = save_backup
	assert_eq(ticks[0], 3)


# ── partida nueva: Youn inicial ───────────────────────────────────────────────

func test_partida_nueva_registra_el_youn_inicial() -> void:
	var save := PlayerSaveData.new()
	GameState.setup_starting_youn(save)
	assert_eq(save.current_youn_path, GameState.STARTING_YOUN_PATH)
	assert_true(ResourceLoader.exists(save.current_youn_path))


func test_partida_nueva_tiene_las_8_stats_iniciales() -> void:
	var save := PlayerSaveData.new()
	GameState.setup_starting_youn(save)
	for key in YounStats.KEYS:
		assert_eq(save.youn_stats.get(key), GameState.STARTING_STATS[key], key)


func test_partida_nueva_arranca_la_etapa_ahora() -> void:
	var save := PlayerSaveData.new()
	GameState.setup_starting_youn(save)
	assert_almost_eq(save.stage_entered_total_hour, GameState.get_total_hours(), 0.01)


func test_el_youn_inicial_es_rookie() -> void:
	var youn: YounData = load(GameState.STARTING_YOUN_PATH)
	assert_eq(youn.stage, "adolescente")
