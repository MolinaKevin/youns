extends GutTest

const HUNGRY_DURATION := 1.5
const ACTIVATION_HOUR := 24.0  # día 1, medianoche


func before_each() -> void:
	GameState.player_save = PlayerSaveData.new()
	GameState.current_day = 1
	GameState.time_of_day_hours = 0.0
	StatsManager.active_states.clear()
	StatsManager.active_states["hungry"] = {"hour": ACTIVATION_HOUR, "stat_value": 100.0}


func after_each() -> void:
	StatsManager.active_states.clear()
	GameState.player_save = null


func _set_time_elapsed(hours: float) -> void:
	GameState.time_of_day_hours = hours  # día 1 → total = 24 + hours


# ── duración ──────────────────────────────────────────────────────────────────

func test_hungry_no_expira_antes_de_tiempo() -> void:
	_set_time_elapsed(HUNGRY_DURATION - 0.1)
	StatsManager.check_emotions()
	assert_true("hungry" in StatsManager.active_states)


func test_hungry_expira_al_cumplirse_el_tiempo() -> void:
	_set_time_elapsed(HUNGRY_DURATION)
	StatsManager.check_emotions()
	assert_false("hungry" in StatsManager.active_states)


# ── penalizaciones al expirar ─────────────────────────────────────────────────

func test_hungry_expirado_reduce_energia() -> void:
	GameState.player_save.energia = 100
	_set_time_elapsed(HUNGRY_DURATION)
	StatsManager.check_emotions()
	assert_eq(GameState.player_save.energia, 70)


func test_hungry_expirado_aumenta_estres() -> void:
	GameState.player_save.estres = 0
	_set_time_elapsed(HUNGRY_DURATION)
	StatsManager.check_emotions()
	assert_eq(GameState.player_save.estres, 30)


func test_hungry_expirado_reduce_salud() -> void:
	GameState.player_save.salud = 100
	_set_time_elapsed(HUNGRY_DURATION)
	StatsManager.check_emotions()
	assert_eq(GameState.player_save.salud, 60)


func test_hungry_expirado_resetea_hambre() -> void:
	GameState.player_save.hambre = 100
	_set_time_elapsed(HUNGRY_DURATION)
	StatsManager.check_emotions()
	assert_eq(GameState.player_save.hambre, 0)


func test_hungry_expirado_suma_care_mistake() -> void:
	GameState.player_save.care_mistakes = 0
	_set_time_elapsed(HUNGRY_DURATION)
	StatsManager.check_emotions()
	assert_eq(GameState.player_save.care_mistakes, 1)
