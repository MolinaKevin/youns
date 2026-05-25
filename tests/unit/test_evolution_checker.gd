extends GutTest

const WILDCARD_CAMPEON := "res://data/youns/nguruvilu_campeon.tres"

var _save_day: int
var _save_hour: float


func before_each() -> void:
	_save_day = GameState.current_day
	_save_hour = GameState.time_of_day_hours
	GameState.current_day = 10
	GameState.time_of_day_hours = 0.0


func after_each() -> void:
	GameState.current_day = _save_day
	GameState.time_of_day_hours = _save_hour


func _make_save(youn_path: String, days_in_stage: float) -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.current_youn_path = youn_path
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


func test_nguruvilu_campeon_es_comodin() -> void:
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_true(youn.is_wildcard)


func test_nguruvilu_campeon_es_campeon() -> void:
	var youn := load(WILDCARD_CAMPEON) as YounData
	assert_eq(youn.stage, "campeon")
