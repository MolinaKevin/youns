extends GutTest

var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()


# ── sick ──────────────────────────────────────────────────────────────────────

func test_sick_no_dispara_con_salud_plena() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sick.tres")
	save.salud = 100
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_sick_probabilidad_muy_baja_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sick.tres")
	save.salud = 70  # la curva termina en x≈0.526 con y≈0.045, el piso no llega a 0
	assert_lt(rule.evaluate({"save": save}), 0.1)


func test_sick_dispara_con_salud_minima() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sick.tres")
	save.salud = 0
	assert_gt(rule.evaluate({"save": save}), 0.5)


# ── tired ─────────────────────────────────────────────────────────────────────

func test_tired_no_dispara_con_energia_plena() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/tired.tres")
	save.energia = 100
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_tired_no_dispara_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/tired.tres")
	save.energia = 70  # la curva termina en x≈0.584, acá ya es 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.01)


func test_tired_dispara_con_energia_minima() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/tired.tres")
	save.energia = 0
	assert_gt(rule.evaluate({"save": save}), 0.5)


# ── hungry ────────────────────────────────────────────────────────────────────

func test_hungry_no_dispara_con_hambre_minima() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/hungry.tres")
	save.hambre = 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_hungry_probabilidad_muy_baja_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/hungry.tres")
	save.hambre = 60  # la curva empieza en x≈0.705 con y≈0.034, el piso no llega a 0
	assert_lt(rule.evaluate({"save": save}), 0.1)


func test_hungry_dispara_con_hambre_maxima() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/hungry.tres")
	save.hambre = 100
	assert_almost_eq(rule.evaluate({"save": save}), 1.0, 0.05)


# ── sad ───────────────────────────────────────────────────────────────────────

func test_sad_no_dispara_con_felicidad_plena() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sad.tres")
	save.felicidad = 100
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_sad_no_dispara_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sad.tres")
	save.felicidad = 50  # la curva termina en x≈0.347, acá ya es 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.01)


func test_sad_dispara_con_felicidad_minima() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sad.tres")
	save.felicidad = 0
	assert_gt(rule.evaluate({"save": save}), 0.7)


# ── stressed ──────────────────────────────────────────────────────────────────

func test_stressed_no_dispara_con_estres_minimo() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/stressed.tres")
	save.estres = 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_stressed_no_dispara_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/stressed.tres")
	save.estres = 30  # la curva empieza en x≈0.422, acá es 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.01)


func test_stressed_dispara_con_estres_maximo() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/stressed.tres")
	save.estres = 100
	assert_gt(rule.evaluate({"save": save}), 0.5)


# ── bored ─────────────────────────────────────────────────────────────────────

func test_bored_no_dispara_con_aburrimiento_minimo() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/bored.tres")
	save.aburrimiento = 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_bored_no_dispara_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/bored.tres")
	save.aburrimiento = 60  # la curva empieza en x≈0.775, acá es 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.01)


func test_bored_dispara_con_aburrimiento_maximo() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/bored.tres")
	save.aburrimiento = 100
	assert_gt(rule.evaluate({"save": save}), 0.2)


# ── bathroom ──────────────────────────────────────────────────────────────────

func test_bathroom_no_dispara_con_ganas_minimas() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/bathroom.tres")
	save.ganas_bano = 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.05)


func test_bathroom_no_dispara_antes_del_threshold() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/bathroom.tres")
	save.ganas_bano = 20  # la curva empieza en x≈0.318, acá es 0
	assert_almost_eq(rule.evaluate({"save": save}), 0.0, 0.01)


func test_bathroom_dispara_con_ganas_maximas() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/bathroom.tres")
	save.ganas_bano = 100
	assert_almost_eq(rule.evaluate({"save": save}), 1.0, 0.05)


# ── sleep ─────────────────────────────────────────────────────────────────────

func test_sleep_dispara_dentro_de_la_ventana_horaria() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sleep.tres")
	var youn := YounData.new()
	youn.sleep_hour = 22
	youn.wake_hour = 7
	GameState.time_of_day_hours = 23.0
	assert_eq(rule.evaluate({"save": save, "youn_data": youn}), 1.0)


func test_sleep_no_dispara_fuera_de_la_ventana_horaria() -> void:
	var rule: EmotionRule = load("res://data/emotions/rules/sleep.tres")
	var youn := YounData.new()
	youn.sleep_hour = 22
	youn.wake_hour = 7
	GameState.time_of_day_hours = 12.0
	assert_eq(rule.evaluate({"save": save, "youn_data": youn}), 0.0)
