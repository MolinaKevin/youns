extends GutTest

const WILDCARD_CAMPEON := "res://data/youns/nguruvilu_campeon.tres"

var _save_day: int
var _save_hour: float


func before_each() -> void:
	_save_day = GameState.current_day
	_save_hour = GameState.time_of_day_hours
	GameState.current_day = 10
	GameState.time_of_day_hours = 0.0
	GameState.player_save = PlayerSaveData.new()
	StatsManager.active_states.clear()
	StatsManager._emotion_block_count = 0


func after_each() -> void:
	GameState.current_day = _save_day
	GameState.time_of_day_hours = _save_hour
	GameState.player_save = null
	StatsManager.active_states.clear()
	StatsManager._emotion_block_count = 0


func _make_rookie_save(days_in_stage: float) -> PlayerSaveData:
	var ps := PlayerSaveData.new()
	ps.current_youn_path = "res://data/youns/pombero.tres"
	ps.stage_entered_total_hour = GameState.get_total_hours() - days_in_stage * 24.0
	return ps


# ── check_evolution ───────────────────────────────────────────────────────────

func test_check_evolution_no_hace_nada_sin_save() -> void:
	GameState.player_save = null
	StatsManager.check_evolution()
	assert_eq(StatsManager.active_states.size(), 0)


func test_check_evolution_no_hace_nada_sin_current_youn_path() -> void:
	GameState.player_save.current_youn_path = ""
	StatsManager.check_evolution()
	assert_eq(StatsManager.active_states.size(), 0)


func test_check_evolution_no_hace_nada_si_no_paso_el_tiempo() -> void:
	GameState.player_save = _make_rookie_save(2.0)
	StatsManager.check_evolution()
	assert_eq(GameState.player_save.pending_evolution_path, "")


func test_check_evolution_setea_pending_evolution_path_al_comodin() -> void:
	GameState.player_save = _make_rookie_save(3.0)
	StatsManager.check_evolution()
	assert_eq(GameState.player_save.pending_evolution_path, WILDCARD_CAMPEON)


func test_check_evolution_activa_emocion_evolving() -> void:
	GameState.player_save = _make_rookie_save(3.0)
	StatsManager.check_evolution()
	assert_true("evolving" in StatsManager.active_states)


func test_check_evolution_guarda_target_youn_path_en_active_states() -> void:
	GameState.player_save = _make_rookie_save(3.0)
	StatsManager.check_evolution()
	assert_eq(StatsManager.active_states["evolving"]["target_youn_path"], WILDCARD_CAMPEON)


func test_check_evolution_bloquea_emociones() -> void:
	GameState.player_save = _make_rookie_save(3.0)
	StatsManager.check_evolution()
	assert_true(StatsManager.emotions_blocked)


func test_check_evolution_no_hace_nada_si_reencarnacion() -> void:
	var ps := PlayerSaveData.new()
	ps.current_youn_path = WILDCARD_CAMPEON
	ps.stage_entered_total_hour = GameState.get_total_hours() - 6.0 * 24.0
	GameState.player_save = ps
	StatsManager.check_evolution()
	assert_eq(ps.pending_evolution_path, "")


# ── complete_evolution ────────────────────────────────────────────────────────

func test_complete_evolution_no_hace_nada_sin_pending_path() -> void:
	GameState.player_save.pending_evolution_path = ""
	StatsManager.complete_evolution()
	assert_eq(GameState.player_save.current_youn_path, "")


func test_complete_evolution_actualiza_current_youn_path() -> void:
	GameState.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.complete_evolution()
	assert_eq(GameState.player_save.current_youn_path, WILDCARD_CAMPEON)


func test_complete_evolution_actualiza_stage_entered_total_hour() -> void:
	GameState.player_save.pending_evolution_path = WILDCARD_CAMPEON
	var expected_hour := GameState.get_total_hours()
	StatsManager.complete_evolution()
	assert_almost_eq(GameState.player_save.stage_entered_total_hour, expected_hour, 0.001)


func test_complete_evolution_limpia_pending_evolution_path() -> void:
	GameState.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.complete_evolution()
	assert_eq(GameState.player_save.pending_evolution_path, "")


func test_complete_evolution_limpia_emocion_evolving() -> void:
	GameState.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.active_states["evolving"] = {"hour": 0.0, "stat_value": 100.0}
	StatsManager.complete_evolution()
	assert_false("evolving" in StatsManager.active_states)


func test_complete_evolution_desbloquea_emociones() -> void:
	GameState.player_save.pending_evolution_path = WILDCARD_CAMPEON
	StatsManager.block_emotions()
	StatsManager.complete_evolution()
	assert_false(StatsManager.emotions_blocked)
