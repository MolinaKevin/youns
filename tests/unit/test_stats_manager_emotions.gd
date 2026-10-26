extends GutTest

var _save_backup: PlayerSaveData


func before_each() -> void:
	_save_backup = GameState.player_save
	GameState.player_save = PlayerSaveData.new()
	StatsManager.active_states.clear()


func after_each() -> void:
	StatsManager.active_states.clear()
	GameState.player_save = _save_backup


# ── hungry <-> bathroom ───────────────────────────────────────────────────────

func test_hungry_activo_bloquea_bathroom_en_evaluacion() -> void:
	GameState.player_save.ganas_bano = 100
	StatsManager.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("bathroom" in StatsManager.active_states)


func test_bathroom_activo_bloquea_hungry_en_evaluacion() -> void:
	GameState.player_save.hambre = 100
	StatsManager.active_states["bathroom"] = {"hour": 0.0, "stat_value": 100.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("hungry" in StatsManager.active_states)


# ── sad bloquea stressed y bored ──────────────────────────────────────────────

func test_sad_activo_bloquea_stressed_en_evaluacion() -> void:
	GameState.player_save.estres = 100
	StatsManager.active_states["sad"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("stressed" in StatsManager.active_states)


func test_sad_activo_bloquea_bored_en_evaluacion() -> void:
	GameState.player_save.aburrimiento = 100
	StatsManager.active_states["sad"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("bored" in StatsManager.active_states)


# ── sick bloquea sad, stressed y bored ───────────────────────────────────────

func test_sick_activo_bloquea_sad_en_evaluacion() -> void:
	GameState.player_save.felicidad = 0
	StatsManager.active_states["sick"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("sad" in StatsManager.active_states)


func test_sick_activo_bloquea_stressed_en_evaluacion() -> void:
	GameState.player_save.estres = 100
	StatsManager.active_states["sick"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("stressed" in StatsManager.active_states)


func test_sick_activo_bloquea_bored_en_evaluacion() -> void:
	GameState.player_save.aburrimiento = 100
	StatsManager.active_states["sick"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("bored" in StatsManager.active_states)


# ── salida cuando la stat mejora ─────────────────────────────────────────────

func test_sad_se_va_cuando_la_felicidad_sube() -> void:
	# felicidad 100: la curva de sad da 0, así que al re-tirar se va seguro
	GameState.player_save.felicidad = 100
	StatsManager.active_states["sad"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("sad" in StatsManager.active_states)


func test_sad_no_se_va_si_la_felicidad_sigue_igual() -> void:
	GameState.player_save.felicidad = 0
	StatsManager.active_states["sad"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager.evaluate_emotion_rules()

	assert_true("sad" in StatsManager.active_states)


func test_tired_se_va_cuando_la_energia_sube() -> void:
	GameState.player_save.energia = 100
	StatsManager.active_states["tired"] = {"hour": 0.0, "stat_value": 5.0}

	StatsManager.evaluate_emotion_rules()

	assert_false("tired" in StatsManager.active_states)


func test_hungry_sigue_saliendo_cuando_el_hambre_baja() -> void:
	GameState.player_save.hambre = 0
	StatsManager.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}
	var hits := 0
	# la curva de hungry no llega a 0 (3,4%): basta con que salga casi siempre
	for i in 20:
		StatsManager.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}
		StatsManager.evaluate_emotion_rules()
		if not "hungry" in StatsManager.active_states:
			hits += 1
	assert_gt(hits, 12)


# ── sick y el flag enfermo ───────────────────────────────────────────────────

func test_enfermar_muestra_sick() -> void:
	StatsManager.set_enfermo(true)
	assert_true("sick" in StatsManager.active_states)


func test_mostrar_sick_enferma_al_youn() -> void:
	StatsManager.show_emotion("sick")
	assert_true(GameState.player_save.enfermo)


func test_curar_saca_sick() -> void:
	StatsManager.set_enfermo(true)
	StatsManager.set_enfermo(false)
	assert_false("sick" in StatsManager.active_states)
	assert_false(GameState.player_save.enfermo)


func test_sick_no_se_va_aunque_la_salud_suba() -> void:
	StatsManager.set_enfermo(true)
	GameState.player_save.salud = 100

	StatsManager.evaluate_emotion_rules()

	assert_true("sick" in StatsManager.active_states)


func test_check_status_vuelve_a_mostrar_sick_si_esta_enfermo() -> void:
	GameState.player_save.enfermo = true
	StatsManager.check_status()
	assert_true("sick" in StatsManager.active_states)
