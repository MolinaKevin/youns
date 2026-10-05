extends GutTest

# Tests de las 8 estadísticas del Youn: valores actuales en la partida, base de
# cada Youn, ganancias y la regla al evolucionar (el nuevo Youn suma o
# multiplica las actuales).

const POMBERO := "res://data/youns/pombero.tres"
const CAMPEON := "res://data/youns/mboi_tui.tres"


func _youn(base: Dictionary) -> YounData:
	var y := YounData.new()
	y.base_stats = YounStats.new()
	for key in base:
		y.base_stats.set(key, base[key])
	return y


func _evolving_to(mode: YounEvolutionStats.Mode, values: Dictionary) -> YounData:
	var y := YounData.new()
	y.evolution_stats = YounEvolutionStats.new()
	y.evolution_stats.mode = mode
	for key in values:
		y.evolution_stats.set(key, values[key])
	return y


func test_start_life_copia_la_base_y_no_hay_nada_ganado() -> void:
	var save := PlayerSaveData.new()
	save.youn_stat_gains = {"fuerza": 99}
	YounStatRules.start_life(save, _youn({"fuerza": 40, "constitucion": 50}))
	assert_eq(YounStatRules.current(save, "fuerza"), 40)
	assert_eq(YounStatRules.current(save, "constitucion"), 50)
	assert_eq(YounStatRules.current(save, "espiritu"), 0)
	assert_true(save.youn_stat_gains.is_empty())


func test_start_life_tiene_las_8_estadisticas() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({}))
	for key in YounStats.KEYS:
		assert_true(save.youn_stats.has(key), key)


func test_gain_suma_a_la_actual_y_lo_anota_como_ganado() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 40}))
	YounStatRules.gain(save, "fuerza", 15)
	YounStatRules.gain(save, "fuerza", 5)
	assert_eq(YounStatRules.current(save, "fuerza"), 60)
	assert_eq(save.youn_stat_gains["fuerza"], 20)


func test_gain_many_suma_varias() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 40, "agilidad": 30}))
	YounStatRules.gain_many(save, {"fuerza": 10, "agilidad": 5})
	assert_eq(YounStatRules.current(save, "fuerza"), 50)
	assert_eq(YounStatRules.current(save, "agilidad"), 35)


func test_gain_no_cambia_la_base_del_youn() -> void:
	var save := PlayerSaveData.new()
	var youn := _youn({"fuerza": 40})
	YounStatRules.start_life(save, youn)
	YounStatRules.gain(save, "fuerza", 25)
	assert_eq(youn.base_stats.fuerza, 40)


func test_apply_evolution_sumar_suma_a_las_actuales() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 40, "constitucion": 50}))
	YounStatRules.gain(save, "fuerza", 20)
	YounStatRules.apply_evolution(save, _evolving_to(YounEvolutionStats.Mode.SUMAR, {"fuerza": 30}))
	assert_eq(YounStatRules.current(save, "fuerza"), 90)         # 40 + 20 + 30
	assert_eq(YounStatRules.current(save, "constitucion"), 50)   # sin cambio


func test_apply_evolution_multiplicar_aplica_el_factor() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 100, "agilidad": 55}))
	var numemon := _evolving_to(YounEvolutionStats.Mode.MULTIPLICAR, {})
	for key in YounStats.KEYS:
		numemon.evolution_stats.set(key, 0.8)
	YounStatRules.apply_evolution(save, numemon)
	assert_eq(YounStatRules.current(save, "fuerza"), 80)
	assert_eq(YounStatRules.current(save, "agilidad"), 44)   # 55 * 0.8
	assert_eq(YounStatRules.current(save, "espiritu"), 0)


func test_apply_evolution_redondea_y_no_baja_de_cero() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 10, "mente": 5}))
	YounStatRules.apply_evolution(save, _evolving_to(YounEvolutionStats.Mode.SUMAR, {"fuerza": 2.6, "mente": -20}))
	assert_eq(YounStatRules.current(save, "fuerza"), 13)
	assert_eq(YounStatRules.current(save, "mente"), 0)


func test_las_evoluciones_se_acumulan() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 10}))
	YounStatRules.gain(save, "fuerza", 5)
	YounStatRules.apply_evolution(save, _evolving_to(YounEvolutionStats.Mode.SUMAR, {"fuerza": 20}))
	YounStatRules.gain(save, "fuerza", 7)
	YounStatRules.apply_evolution(save, _evolving_to(YounEvolutionStats.Mode.SUMAR, {"fuerza": 50}))
	assert_eq(YounStatRules.current(save, "fuerza"), 92)  # 10 + 5 + 20 + 7 + 50


func test_apply_evolution_sin_evolution_stats_no_cambia_nada() -> void:
	var save := PlayerSaveData.new()
	YounStatRules.start_life(save, _youn({"fuerza": 40}))
	YounStatRules.gain(save, "fuerza", 8)
	YounStatRules.apply_evolution(save, YounData.new())
	assert_eq(YounStatRules.current(save, "fuerza"), 48)


func test_ensure_initialized_usa_el_youn_actual_si_no_hay_stats() -> void:
	var save := PlayerSaveData.new()
	save.current_youn_path = POMBERO
	YounStatRules.ensure_initialized(save)
	var base: YounStats = (load(POMBERO) as YounData).base_stats
	assert_eq(YounStatRules.current(save, "agilidad"), base.agilidad)


func test_ensure_initialized_sin_youn_actual_usa_el_fallback() -> void:
	var save := PlayerSaveData.new()
	var pombero: YounData = load(POMBERO)
	YounStatRules.ensure_initialized(save, pombero)
	assert_eq(save.youn_stats.size(), YounStats.KEYS.size())
	assert_eq(YounStatRules.current(save, "agilidad"), pombero.base_stats.agilidad)


func test_reward_sobre_stats_vacias_arranca_de_la_base() -> void:
	# antes: sumar sobre stats vacías dejaba solo esa stat y el resto en 0
	var save := PlayerSaveData.new()
	var pombero: YounData = load(POMBERO)
	YounStatRules.reward(save, {"fuerza": 10}, pombero)
	assert_eq(YounStatRules.current(save, "fuerza"), pombero.base_stats.fuerza + 10)
	assert_eq(YounStatRules.current(save, "constitucion"), pombero.base_stats.constitucion)


func test_reward_de_combate_suma_1_a_cada_stat() -> void:
	var save := PlayerSaveData.new()
	var pombero: YounData = load(POMBERO)
	YounStatRules.start_life(save, pombero)
	var gains := {}
	for key in YounStats.KEYS:
		gains[key] = 1
	YounStatRules.reward(save, gains, pombero)
	for key in YounStats.KEYS:
		assert_eq(YounStatRules.current(save, key), int(pombero.base_stats.get(key)) + 1, key)


func test_ensure_initialized_no_pisa_stats_existentes() -> void:
	var save := PlayerSaveData.new()
	save.current_youn_path = POMBERO
	save.youn_stats = {"fuerza": 999}
	YounStatRules.ensure_initialized(save)
	assert_eq(YounStatRules.current(save, "fuerza"), 999)


func test_youns_con_etapa_tienen_estadisticas_base_y_de_evolucion() -> void:
	for path in [POMBERO, "res://data/youns/nguruvilu.tres", CAMPEON]:
		var youn := load(path) as YounData
		assert_not_null(youn.base_stats, path)
		assert_not_null(youn.evolution_stats, path)


func test_migrate_keys_pasa_vitalidad_a_constitucion() -> void:
	var save := PlayerSaveData.new()
	save.youn_stats = {"vitalidad": 50, "fuerza": 40}
	save.youn_stat_gains = {"vitalidad": 7}
	YounStatRules.migrate_keys(save)
	assert_eq(YounStatRules.current(save, "constitucion"), 50)
	assert_eq(YounStatRules.current(save, "fuerza"), 40)
	assert_false(save.youn_stats.has("vitalidad"))
	assert_eq(int(save.youn_stat_gains["constitucion"]), 7)


func test_migrate_keys_pasa_energia_a_mente() -> void:
	var save := PlayerSaveData.new()
	save.youn_stats = {"energia": 40}
	YounStatRules.migrate_keys(save)
	assert_eq(YounStatRules.current(save, "mente"), 40)
	assert_false(save.youn_stats.has("energia"))


func test_margen_de_iniciativa_por_agilidad() -> void:
	assert_eq(YounStatRules.initiative_shift({"agilidad": 0}), 0)
	assert_eq(YounStatRules.initiative_shift({"agilidad": 50}), 3)
	assert_eq(YounStatRules.initiative_shift({"agilidad": 75}), 6)
	assert_eq(YounStatRules.initiative_shift({"agilidad": 100}), 10)
	assert_eq(YounStatRules.initiative_shift({"agilidad": 60}), 4)
	assert_gt(YounStatRules.initiative_shift({"agilidad": 150}), 10)
	assert_eq(YounStatRules.initiative_shift({}), 0)


func test_reduccion_de_estados_por_resistencia() -> void:
	assert_eq(YounStatRules.status_reduction({"resistencia": 50}), 0)
	assert_eq(YounStatRules.status_reduction({"resistencia": 74}), 0)
	assert_eq(YounStatRules.status_reduction({"resistencia": 75}), 1)
	assert_eq(YounStatRules.status_reduction({"resistencia": 100}), 2)
	assert_eq(YounStatRules.status_reduction({"resistencia": 25}), -1)
	assert_eq(YounStatRules.status_reduction({}), 0)


func test_max_mp_sale_de_la_mente() -> void:
	assert_eq(YounStatRules.max_mp({"mente": 40}), 40 * YounStatRules.MP_PER_MENTE)
	assert_eq(YounStatRules.max_mp({}), 0)


func test_max_hp_sale_de_la_constitucion() -> void:
	assert_eq(YounStatRules.max_hp({"constitucion": 50}), 50 * YounStatRules.HP_PER_CONSTITUCION)
	assert_eq(YounStatRules.max_hp({"constitucion": 0}), 1)
	assert_eq(YounStatRules.max_hp({}), YounStatRules.DEFAULT_MAX_HP)


# ── Integración con la evolución de StatsManager ──────────────────────────────

func test_complete_evolution_aplica_la_evolucion_sobre_las_actuales() -> void:
	var previous := GameState.player_save
	var save := PlayerSaveData.new()
	save.current_youn_path = POMBERO
	YounStatRules.start_life(save, load(POMBERO) as YounData)
	YounStatRules.gain(save, "fuerza", 12)
	save.pending_evolution_path = CAMPEON
	GameState.player_save = save

	StatsManager.complete_evolution()

	var pombero_base: YounStats = (load(POMBERO) as YounData).base_stats
	var expected := (load(CAMPEON) as YounData).evolution_stats.apply_to(
		{"fuerza": pombero_base.fuerza + 12, "espiritu": pombero_base.espiritu})
	assert_eq(YounStatRules.current(save, "fuerza"), expected["fuerza"])
	assert_eq(YounStatRules.current(save, "espiritu"), expected["espiritu"])
	GameState.player_save = previous
	StatsManager.active_states.clear()
	StatsManager._emotion_block_count = 0
