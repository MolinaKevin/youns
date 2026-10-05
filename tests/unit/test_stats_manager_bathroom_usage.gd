extends GutTest

# Asume StatsManager.attend_bathroom(rng: RandomNumberGenerator = null)
# para el caso normal (sin penalizaciones).
# apply_bathroom_accident() sigue siendo el caso de accidente (con penalizaciones).

var _youn_backup: Node


func before_each() -> void:
	GameState.player_save = PlayerSaveData.new()
	StatsManager.active_states.clear()
	StatsManager.active_states["bathroom"] = {"hour": 0.0, "stat_value": 100.0}
	GameState.player_save.ganas_bano = 80
	GameState.player_save.poop_pending = 2.0
	GameState.player_save.weight = 20.0
	_youn_backup = PartyManager.youn
	PartyManager.youn = null


func after_each() -> void:
	StatsManager.active_states.clear()
	GameState.player_save = null
	PartyManager.youn = _youn_backup


# ── visita normal — attend_bathroom() ────────────────────────────────────────

func test_attend_bathroom_limpia_emocion() -> void:
	StatsManager.attend_bathroom()
	assert_false("bathroom" in StatsManager.active_states)


func test_attend_bathroom_resetea_ganas_bano() -> void:
	StatsManager.attend_bathroom()
	assert_eq(GameState.player_save.ganas_bano, 0)


func test_attend_bathroom_resetea_poop_pending() -> void:
	StatsManager.attend_bathroom()
	assert_almost_eq(GameState.player_save.poop_pending, 0.0, 0.001)


func test_attend_bathroom_reduce_peso() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	StatsManager.attend_bathroom(rng)
	assert_lt(GameState.player_save.weight, 20.0)


func test_attend_bathroom_no_aplica_penalizacion_felicidad() -> void:
	GameState.player_save.felicidad = 100
	StatsManager.attend_bathroom()
	assert_eq(GameState.player_save.felicidad, 100)


func test_attend_bathroom_no_aplica_penalizacion_salud() -> void:
	GameState.player_save.salud = 100
	StatsManager.attend_bathroom()
	assert_eq(GameState.player_save.salud, 100)


func test_attend_bathroom_no_suma_care_mistake() -> void:
	GameState.player_save.care_mistakes = 0
	StatsManager.attend_bathroom()
	assert_eq(GameState.player_save.care_mistakes, 0)


# ── accidente — apply_bathroom_accident() ────────────────────────────────────

func test_accidente_limpia_emocion() -> void:
	StatsManager.apply_bathroom_accident()
	assert_false("bathroom" in StatsManager.active_states)


func test_accidente_resetea_ganas_bano() -> void:
	StatsManager.apply_bathroom_accident()
	assert_eq(GameState.player_save.ganas_bano, 0)


func test_accidente_resetea_poop_pending() -> void:
	StatsManager.apply_bathroom_accident()
	assert_almost_eq(GameState.player_save.poop_pending, 0.0, 0.001)


func test_accidente_reduce_peso() -> void:
	StatsManager.apply_bathroom_accident()
	assert_lt(GameState.player_save.weight, 20.0)


func test_accidente_aplica_penalizacion_felicidad() -> void:
	GameState.player_save.felicidad = 100
	StatsManager.apply_bathroom_accident()
	assert_eq(GameState.player_save.felicidad, 90)


func test_accidente_aplica_penalizacion_salud() -> void:
	GameState.player_save.salud = 100
	StatsManager.apply_bathroom_accident()
	assert_eq(GameState.player_save.salud, 95)


func test_accidente_suma_care_mistake() -> void:
	GameState.player_save.care_mistakes = 0
	StatsManager.apply_bathroom_accident()
	assert_eq(GameState.player_save.care_mistakes, 1)


# ── vencimiento — la hora de bathroom se cumple sin ir al baño ───────────────

func _vencer_bathroom() -> void:
	GameState.current_day = 1
	GameState.time_of_day_hours = 12.0
	# activado hace 2 h (dura 1 h)
	StatsManager.active_states["bathroom"] = {"hour": GameState.get_total_hours() - 2.0, "stat_value": 100.0}
	StatsManager.check_emotions()


func test_bathroom_vencido_vacia_las_ganas() -> void:
	GameState.player_save.ganas_bano = 100
	_vencer_bathroom()
	assert_eq(GameState.player_save.ganas_bano, 0)
	assert_false("bathroom" in StatsManager.active_states)


func test_bathroom_vencido_aplica_la_perdida_de_peso() -> void:
	_vencer_bathroom()
	assert_lt(GameState.player_save.weight, 20.0)
	assert_eq(GameState.player_save.poop_pending, 0.0)


func test_bathroom_vencido_no_vuelve_a_aparecer_enseguida() -> void:
	# antes: las ganas quedaban en 100 y bathroom reaparecía y vencía en loop
	GameState.player_save.ganas_bano = 100
	_vencer_bathroom()
	StatsManager._evaluate_emotion_rules()
	assert_false("bathroom" in StatsManager.active_states)

