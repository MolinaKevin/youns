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

	StatsManager._evaluate_emotion_rules()

	assert_false("bathroom" in StatsManager.active_states)


func test_bathroom_activo_bloquea_hungry_en_evaluacion() -> void:
	GameState.player_save.hambre = 100
	StatsManager.active_states["bathroom"] = {"hour": 0.0, "stat_value": 100.0}

	StatsManager._evaluate_emotion_rules()

	assert_false("hungry" in StatsManager.active_states)


# ── sad bloquea stressed y bored ──────────────────────────────────────────────

func test_sad_activo_bloquea_stressed_en_evaluacion() -> void:
	GameState.player_save.estres = 100
	StatsManager.active_states["sad"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager._evaluate_emotion_rules()

	assert_false("stressed" in StatsManager.active_states)


func test_sad_activo_bloquea_bored_en_evaluacion() -> void:
	GameState.player_save.aburrimiento = 100
	StatsManager.active_states["sad"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager._evaluate_emotion_rules()

	assert_false("bored" in StatsManager.active_states)


# ── sick bloquea sad, stressed y bored ───────────────────────────────────────

func test_sick_activo_bloquea_sad_en_evaluacion() -> void:
	GameState.player_save.felicidad = 0
	StatsManager.active_states["sick"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager._evaluate_emotion_rules()

	assert_false("sad" in StatsManager.active_states)


func test_sick_activo_bloquea_stressed_en_evaluacion() -> void:
	GameState.player_save.estres = 100
	StatsManager.active_states["sick"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager._evaluate_emotion_rules()

	assert_false("stressed" in StatsManager.active_states)


func test_sick_activo_bloquea_bored_en_evaluacion() -> void:
	GameState.player_save.aburrimiento = 100
	StatsManager.active_states["sick"] = {"hour": 0.0, "stat_value": 0.0}

	StatsManager._evaluate_emotion_rules()

	assert_false("bored" in StatsManager.active_states)
