extends GutTest

# Asume que existirá StatsManager.emotion_service.on_wake_up(sleep_duration_hours: float)
#
# Comportamiento esperado al despertar:
# - tired        → se elimina (descansó)
# - bathroom     → si ya pasó el 50% de su duración, se expira con penalización
# - resto        → se pausean: su hora de activación se corre hacia adelante
#                  por el tiempo dormido, para que el timer no avance

const BATHROOM_DURATION := 1.0
const BATHROOM_HALF := BATHROOM_DURATION * 0.5
const ACTIVATION_HOUR := 24.0  # día 1, medianoche


func before_each() -> void:
	GameState.save_service.player_save = PlayerSaveData.new()
	GameState.current_day = 1
	GameState.time_of_day_hours = 0.0
	StatsManager.emotion_service.active_states.clear()


func after_each() -> void:
	StatsManager.emotion_service.active_states.clear()
	GameState.save_service.player_save = null


# ── tired ─────────────────────────────────────────────────────────────────────

func test_tired_se_elimina_al_despertar() -> void:
	StatsManager.emotion_service.active_states["tired"] = EmotionStateEntry.make(ACTIVATION_HOUR, 0.0)
	StatsManager.emotion_service.on_wake_up(8.0)
	assert_false("tired" in StatsManager.emotion_service.active_states)


func test_tired_no_aplica_penalizacion_al_eliminarse() -> void:
	GameState.save_service.player_save.energia = 50
	StatsManager.emotion_service.active_states["tired"] = EmotionStateEntry.make(ACTIVATION_HOUR, 0.0)
	StatsManager.emotion_service.on_wake_up(8.0)
	assert_eq(GameState.save_service.player_save.energia, 50)


# ── bathroom ──────────────────────────────────────────────────────────────────

func test_bathroom_expira_al_despertar_si_supero_50_porciento_de_duracion() -> void:
	# activado en hora 24.0, ahora son 24.5 → pasó exactamente el 50%
	GameState.time_of_day_hours = BATHROOM_HALF
	StatsManager.emotion_service.active_states["bathroom"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.on_wake_up(1.0)
	assert_false("bathroom" in StatsManager.emotion_service.active_states)


func test_bathroom_no_expira_y_se_pausea_si_no_supero_50_porciento() -> void:
	# activado en hora 24.0, ahora son 24.4 → pasó menos del 50%
	var sleep_duration := 1.0
	GameState.time_of_day_hours = BATHROOM_HALF - 0.1
	StatsManager.emotion_service.active_states["bathroom"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.on_wake_up(sleep_duration)
	assert_true("bathroom" in StatsManager.emotion_service.active_states)
	assert_almost_eq(
		StatsManager.emotion_service.active_states["bathroom"]["hour"],
		ACTIVATION_HOUR + sleep_duration,
		0.01
	)


func test_bathroom_aplica_penalizacion_de_felicidad_al_expirar_durmiendo() -> void:
	GameState.save_service.player_save.felicidad = 100
	GameState.time_of_day_hours = BATHROOM_HALF
	StatsManager.emotion_service.active_states["bathroom"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.on_wake_up(1.0)
	assert_eq(GameState.save_service.player_save.felicidad, 90)


func test_bathroom_aplica_penalizacion_de_salud_al_expirar_durmiendo() -> void:
	GameState.save_service.player_save.salud = 100
	GameState.time_of_day_hours = BATHROOM_HALF
	StatsManager.emotion_service.active_states["bathroom"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.on_wake_up(1.0)
	assert_eq(GameState.save_service.player_save.salud, 95)


# ── pausa de emociones ────────────────────────────────────────────────────────

func test_hungry_se_pausea_durante_el_sueno() -> void:
	var sleep_duration := 8.0
	StatsManager.emotion_service.active_states["hungry"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.on_wake_up(sleep_duration)
	assert_true("hungry" in StatsManager.emotion_service.active_states)
	assert_almost_eq(
		StatsManager.emotion_service.active_states["hungry"]["hour"],
		ACTIVATION_HOUR + sleep_duration,
		0.01
	)


func test_sad_se_pausea_durante_el_sueno() -> void:
	var sleep_duration := 6.0
	StatsManager.emotion_service.active_states["sad"] = EmotionStateEntry.make(ACTIVATION_HOUR, 0.0)
	StatsManager.emotion_service.on_wake_up(sleep_duration)
	assert_true("sad" in StatsManager.emotion_service.active_states)
	assert_almost_eq(
		StatsManager.emotion_service.active_states["sad"]["hour"],
		ACTIVATION_HOUR + sleep_duration,
		0.01
	)


func test_pausa_no_afecta_a_tired() -> void:
	# tired se elimina, no se pausea
	StatsManager.emotion_service.active_states["tired"] = EmotionStateEntry.make(ACTIVATION_HOUR, 0.0)
	StatsManager.emotion_service.on_wake_up(8.0)
	assert_false("tired" in StatsManager.emotion_service.active_states)


func test_multiples_emociones_se_pausean_correctamente() -> void:
	var sleep_duration := 7.0
	StatsManager.emotion_service.active_states["hungry"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.active_states["sad"]    = {"hour": ACTIVATION_HOUR, "stat_value": 0.0}
	StatsManager.emotion_service.active_states["tired"]  = {"hour": ACTIVATION_HOUR, "stat_value": 0.0}
	StatsManager.emotion_service.on_wake_up(sleep_duration)
	assert_false("tired" in StatsManager.emotion_service.active_states)
	assert_almost_eq(StatsManager.emotion_service.active_states["hungry"]["hour"], ACTIVATION_HOUR + sleep_duration, 0.01)
	assert_almost_eq(StatsManager.emotion_service.active_states["sad"]["hour"], ACTIVATION_HOUR + sleep_duration, 0.01)


# ── sleep ─────────────────────────────────────────────────────────────────────

func test_sleep_se_elimina_al_despertar() -> void:
	StatsManager.emotion_service.active_states["sleep"] = EmotionStateEntry.make(ACTIVATION_HOUR, 100.0)
	StatsManager.emotion_service.on_wake_up(8.0)
	assert_false("sleep" in StatsManager.emotion_service.active_states)
