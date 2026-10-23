extends GutTest

const WILDCARD_CAMPEON := "res://data/youns/mboi_tui.tres"

var _save_day: int
var _save_hour: float


var _zone := ""


func before_each() -> void:
	# Zona fija que ninguna condición usa: los tests no dependen de dónde quedó el jugador.
	_zone = ZoneManager.current_zone
	ZoneManager.enter_zone("crossroads")
	_save_day = GameState.current_day
	_save_hour = GameState.time_of_day_hours
	GameState.current_day = 10
	GameState.time_of_day_hours = 0.0


func after_each() -> void:
	ZoneManager.enter_zone(_zone)
	GameState.current_day = _save_day
	GameState.time_of_day_hours = _save_hour


func _make_save(youn_path: String, days_in_stage: float) -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.current_youn_path = youn_path
	# Con errores de cuidado no llega a 3 condiciones de ningún campeón (un
	# Pombero bien cuidado va a Yaguareté-Abá): cae en el comodín.
	save.care_mistakes = 5
	save.stage_entered_total_hour = GameState.get_total_hours() - days_in_stage * 24.0
	return save


# ── check_conditions ──────────────────────────────────────────────────────────

func test_check_conditions_retorna_vacio_por_defecto() -> void:
	var save := PlayerSaveData.new()
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_eq(EvolutionChecker.check_conditions(save, youn), "")


func test_check_conditions_retorna_vacio_con_youn_null() -> void:
	assert_eq(EvolutionChecker.check_conditions(PlayerSaveData.new(), null), "")


func test_check_conditions_retorna_vacio_con_save_null() -> void:
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_eq(EvolutionChecker.check_conditions(null, youn), "")


# ── try_evolve — guards ───────────────────────────────────────────────────────

func test_try_evolve_retorna_vacio_con_save_null() -> void:
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_eq(EvolutionChecker.try_evolve(null, youn), "")


func test_try_evolve_retorna_vacio_con_youn_null() -> void:
	assert_eq(EvolutionChecker.try_evolve(PlayerSaveData.new(), null), "")


# ── try_evolve — vida maxima rookie (3 dias) ──────────────────────────────────

func test_rookie_no_evoluciona_antes_de_3_dias() -> void:
	var save := _make_save("res://data/youns/pombero.tres", 2.9)
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_eq(EvolutionChecker.try_evolve(save, youn), "")


func test_rookie_evoluciona_al_comodin_exactamente_a_3_dias() -> void:
	var save := _make_save("res://data/youns/pombero.tres", 3.0)
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_eq(EvolutionChecker.try_evolve(save, youn), WILDCARD_CAMPEON)


func test_rookie_evoluciona_al_comodin_si_paso_mas_de_3_dias() -> void:
	var save := _make_save("res://data/youns/pombero.tres", 4.0)
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_eq(EvolutionChecker.try_evolve(save, youn), WILDCARD_CAMPEON)


func test_no_evoluciona_si_no_es_etapa_con_vida_maxima() -> void:
	var save := _make_save("", 99.0)
	var youn := YounData.new()
	youn.stage = "bebe"
	assert_eq(EvolutionChecker.try_evolve(save, youn), "")


# ── try_evolve — vida maxima campeon (6 dias) → reencarnacion ────────────────

func test_campeon_no_muere_antes_de_6_dias() -> void:
	var save := _make_save(WILDCARD_CAMPEON, 5.9)
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_eq(EvolutionChecker.try_evolve(save, youn), "")


func test_campeon_muere_exactamente_a_6_dias() -> void:
	var save := _make_save(WILDCARD_CAMPEON, 6.0)
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_eq(EvolutionChecker.try_evolve(save, youn), EvolutionChecker.REINCARNATE)


func test_campeon_muere_si_paso_mas_de_6_dias() -> void:
	var save := _make_save(WILDCARD_CAMPEON, 8.0)
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_eq(EvolutionChecker.try_evolve(save, youn), EvolutionChecker.REINCARNATE)


# ── YounData.is_wildcard ──────────────────────────────────────────────────────

func test_is_wildcard_es_false_por_defecto() -> void:
	assert_false(YounData.new().is_wildcard)


func test_pombero_no_es_comodin() -> void:
	var youn := load("res://data/youns/pombero.tres") as YounData
	assert_false(youn.is_wildcard)


func test_nguruvilu_no_es_comodin() -> void:
	var youn := load("res://data/youns/nguruvilu.tres") as YounData
	assert_false(youn.is_wildcard)


func test_mboi_tui_es_comodin() -> void:
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_true(youn.is_wildcard)


func test_mboi_tui_es_campeon() -> void:
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_eq(youn.stage, "campeon")


# ── Bebé → Niño (fijo) → Rookie (por condiciones) ─────────────────────────────

const BEBE := "res://data/youns/bebe_1.tres"
const NINO := "res://data/youns/nino_1.tres"
const POMBERO := "res://data/youns/pombero.tres"
const NGURUVILU := "res://data/youns/nguruvilu.tres"


## Un niño listo para evolucionar, con todas las stats en 30 salvo las pedidas.
func _nino_save(stats: Dictionary = {}) -> PlayerSaveData:
	var save := _make_save(NINO, 1.0)
	for key in YounStats.KEYS:
		save.youn_stats[key] = int(stats.get(key, 30))
	return save


func _pick(save: PlayerSaveData) -> String:
	var ctx := {"save": save, "from": load(NINO), "hour": 12.0, "zone": "hub"}
	return EvolutionChecker.pick_target((load(NINO) as YounData).evolves_to, ctx)


func test_bebe_no_evoluciona_antes_de_6_horas() -> void:
	var save := _make_save(BEBE, 5.0 / 24.0)
	assert_eq(EvolutionChecker.try_evolve(save, load(BEBE) as YounData), "")


func test_bebe_evoluciona_a_su_nino_fijo_a_las_6_horas() -> void:
	var save := _make_save(BEBE, 0.25)
	assert_eq(EvolutionChecker.try_evolve(save, load(BEBE) as YounData), NINO)


func test_nino_no_evoluciona_antes_de_cumplir_el_dia() -> void:
	var save := _make_save(NINO, 0.7)
	assert_eq(EvolutionChecker.try_evolve(save, load(NINO) as YounData), "")


func test_nino_evoluciona_al_cumplir_el_dia() -> void:
	var save := _nino_save({"espiritu": 50})
	assert_eq(EvolutionChecker.try_evolve(save, load(NINO) as YounData), NGURUVILU)


func test_stat_dominante_de_pombero_va_a_pombero() -> void:
	for key in ["agilidad", "tecnica", "inteligencia", "mente"]:
		assert_eq(_pick(_nino_save({key: 45})), POMBERO, key)


func test_stat_dominante_de_nguruvilu_va_a_nguruvilu() -> void:
	for key in ["espiritu", "constitucion", "resistencia", "fuerza"]:
		assert_eq(_pick(_nino_save({key: 45})), NGURUVILU, key)


func test_empate_arriba_entre_rookies_va_al_por_defecto() -> void:
	assert_eq(_pick(_nino_save({"agilidad": 45, "espiritu": 45})), POMBERO)


func test_empate_arriba_del_mismo_rookie_va_a_ese() -> void:
	assert_eq(_pick(_nino_save({"espiritu": 45, "fuerza": 45})), NGURUVILU)


func test_dominant_stats_devuelve_las_empatadas() -> void:
	assert_eq(EvolutionChecker.dominant_stats({"fuerza": 10, "agilidad": 10, "mente": 3}), ["fuerza", "agilidad"] as Array[String])


func test_rookies_de_nino_1_se_reparten_las_8_stats() -> void:
	var seen: Array[String] = []
	for path in [POMBERO, NGURUVILU]:
		var youn := load(path) as YounData
		assert_eq(youn.dominant_stats.size(), 4, path)
		assert_eq(youn.intelligences.size(), 1, path)
		for key in youn.dominant_stats:
			assert_false(key in seen, key)
			seen.append(key)
	for key in YounStats.KEYS:
		assert_true(key in seen, key)


# ── Condiciones sueltas ───────────────────────────────────────────────────────

func test_condicion_de_hora_cruza_la_medianoche() -> void:
	var c := EvolutionConditionHour.new()
	c.from_hour = 20.0
	c.to_hour = 5.0
	assert_true(c.is_met({"hour": 23.0}))
	assert_true(c.is_met({"hour": 2.0}))
	assert_false(c.is_met({"hour": 12.0}))
	assert_false(c.is_met({"hour": 5.0}))


func test_condicion_de_valores_usa_min_y_max() -> void:
	var check := EvolutionValueCheck.new()
	check.key = "discipline"
	check.use_min = false
	check.use_max = true
	check.max_value = 50.0
	var c := EvolutionConditionValues.new()
	c.kind = EvolutionCondition.Kind.CRIANZA
	c.checks = [check]
	var save := PlayerSaveData.new()
	save.discipline = 50
	assert_true(c.is_met({"save": save}))
	save.discipline = 51
	assert_false(c.is_met({"save": save}))


func test_condicion_de_inteligencia() -> void:
	var c := EvolutionConditionIntelligence.new()
	c.intelligences = PackedStringArray(["corporal", "logica"])
	assert_true(c.is_met({"from": load(POMBERO)}))
	assert_false(c.is_met({"from": load(NGURUVILU)}))
