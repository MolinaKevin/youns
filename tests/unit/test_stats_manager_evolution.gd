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
	GameState.save_service.player_save = PlayerSaveData.new()
	StatsManager.emotion_service.active_states.clear()
	while StatsManager.emotion_service.is_blocked():
		StatsManager.emotion_service.unblock()


func after_each() -> void:
	ZoneManager.enter_zone(_zone)
	GameState.current_day = _save_day
	GameState.time_of_day_hours = _save_hour
	GameState.save_service.player_save = null
	StatsManager.emotion_service.active_states.clear()
	while StatsManager.emotion_service.is_blocked():
		StatsManager.emotion_service.unblock()


func _make_rookie_save(days_in_stage: float) -> PlayerSaveData:
	var ps := PlayerSaveData.new()
	ps.current_youn_path = "res://data/youns/newen.tres"
	# Sin 3 condiciones de ningún campeón: va al comodín.
	ps.care_mistakes = 5
	ps.stage_entered_total_hour = GameState.get_total_hours() - days_in_stage * 24.0
	return ps


# ── check_evolution ───────────────────────────────────────────────────────────

func test_check_evolution_no_hace_nada_sin_save() -> void:
	GameState.save_service.player_save = null
	StatsManager.life_stage.check_evolution()
	assert_eq(StatsManager.emotion_service.active_states.size(), 0)


func test_check_evolution_no_hace_nada_sin_current_youn_path() -> void:
	GameState.save_service.player_save.current_youn_path = ""
	StatsManager.life_stage.check_evolution()
	assert_eq(StatsManager.emotion_service.active_states.size(), 0)


func test_check_evolution_no_hace_nada_si_no_paso_el_tiempo() -> void:
	GameState.save_service.player_save = _make_rookie_save(2.0)
	StatsManager.life_stage.check_evolution()
	assert_eq(GameState.save_service.player_save.pending_evolution_path, "")


func test_check_evolution_setea_pending_evolution_path_al_comodin() -> void:
	GameState.save_service.player_save = _make_rookie_save(3.0)
	StatsManager.life_stage.check_evolution()
	assert_eq(GameState.save_service.player_save.pending_evolution_path, WILDCARD_CAMPEON)


func test_check_evolution_activa_emocion_evolving() -> void:
	GameState.save_service.player_save = _make_rookie_save(3.0)
	StatsManager.life_stage.check_evolution()
	assert_true("evolving" in StatsManager.emotion_service.active_states)


func test_check_evolution_guarda_target_youn_path_en_active_states() -> void:
	GameState.save_service.player_save = _make_rookie_save(3.0)
	StatsManager.life_stage.check_evolution()
	assert_eq(StatsManager.emotion_service.active_states["evolving"]["target_youn_path"], WILDCARD_CAMPEON)


func test_check_evolution_bloquea_emociones() -> void:
	GameState.save_service.player_save = _make_rookie_save(3.0)
	StatsManager.life_stage.check_evolution()
	assert_true(StatsManager.emotion_service.is_blocked())


func test_check_evolution_al_reencarnar_no_evoluciona_sino_que_muere() -> void:
	var ps := PlayerSaveData.new()
	ps.current_youn_path = WILDCARD_CAMPEON
	ps.stage_entered_total_hour = GameState.get_total_hours() - 6.0 * 24.0
	GameState.save_service.player_save = ps
	StatsManager.life_stage.check_evolution()
	assert_eq(ps.pending_evolution_path, "")
	assert_true("dying" in StatsManager.emotion_service.active_states)


# ── complete_evolution ────────────────────────────────────────────────────────

func test_complete_evolution_no_hace_nada_sin_pending_path() -> void:
	GameState.save_service.player_save.pending_evolution_path = ""
	StatsManager.life_stage.complete_evolution()
	assert_eq(GameState.save_service.player_save.current_youn_path, "")


func test_complete_evolution_actualiza_current_youn_path() -> void:
	GameState.save_service.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.life_stage.complete_evolution()
	assert_eq(GameState.save_service.player_save.current_youn_path, WILDCARD_CAMPEON)


func test_complete_evolution_actualiza_stage_entered_total_hour() -> void:
	GameState.save_service.player_save.pending_evolution_path = WILDCARD_CAMPEON
	var expected_hour := GameState.get_total_hours()
	StatsManager.life_stage.complete_evolution()
	assert_almost_eq(GameState.save_service.player_save.stage_entered_total_hour, expected_hour, 0.001)


func test_complete_evolution_limpia_pending_evolution_path() -> void:
	GameState.save_service.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.life_stage.complete_evolution()
	assert_eq(GameState.save_service.player_save.pending_evolution_path, "")


func test_complete_evolution_limpia_emocion_evolving() -> void:
	GameState.save_service.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.emotion_service.active_states["evolving"] = EmotionStateEntry.make(0.0, 100.0)
	StatsManager.life_stage.complete_evolution()
	assert_false("evolving" in StatsManager.emotion_service.active_states)


func test_complete_evolution_desbloquea_emociones() -> void:
	GameState.save_service.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.emotion_service.block()
	StatsManager.life_stage.complete_evolution()
	assert_false(StatsManager.emotion_service.is_blocked())


# ── complete_evolution: carta característica y cambios de stats ───────────────

func _evolve_to(path: String) -> Dictionary:
	var ps := GameState.save_service.player_save
	ps.current_youn_path = "res://data/youns/nguruvilu.tres"
	YounStatRules.start_life(ps, load(ps.current_youn_path))
	ps.equipped_deck_ids = ["strike", "block"]
	ps.pending_evolution_path = path
	return StatsManager.life_stage.complete_evolution()


func test_completar_evolucion_agrega_la_carta_caracteristica_al_mazo() -> void:
	var to: YounData = load(WILDCARD_CAMPEON)
	var result := _evolve_to(WILDCARD_CAMPEON)
	if to.signature_card == null:
		pass_test("el campeón no tiene carta característica")
		return
	assert_eq(GameState.save_service.player_save.deck.size(), 3)
	assert_eq(result["added_card"], GameState.save_service.player_save.deck[2])
	assert_eq(result["added_card"].id, to.signature_card.id)
	assert_ne(result["added_card"], to.signature_card)


func test_completar_evolucion_devuelve_los_cambios_de_stats() -> void:
	var nguruvilu: YounData = load("res://data/youns/nguruvilu.tres")
	var before := nguruvilu.base_stats.to_dict()
	var result := _evolve_to(WILDCARD_CAMPEON)
	var evo: YounEvolutionStats = (load(WILDCARD_CAMPEON) as YounData).evolution_stats
	var expected: int = evo.apply_to(before)["fuerza"] - before["fuerza"]
	assert_eq(result["stat_changes"].get("fuerza", 0), expected)
	assert_eq((result["to"] as YounData).resource_path, WILDCARD_CAMPEON)
