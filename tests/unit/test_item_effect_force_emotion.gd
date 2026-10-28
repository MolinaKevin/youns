extends GutTest

const VACIADOR_ESTOMAGO := preload("res://data/items/vaciador_estomago.tres")

var save: PlayerSaveData
var _previous_save: PlayerSaveData
var _previous_active_states: Dictionary
var _previous_emotions_blocked := false

func before_each() -> void:
	_previous_save = GameState.player_save
	_previous_active_states = StatsManager.emotion_service.active_states.duplicate(true)
	_previous_emotions_blocked = StatsManager.emotion_service.is_blocked()
	save = PlayerSaveData.new()
	GameState.player_save = save
	StatsManager.emotion_service.active_states.clear()
	while StatsManager.emotion_service.is_blocked():
		StatsManager.emotion_service.unblock()


func after_each() -> void:
	GameState.player_save = _previous_save
	StatsManager.emotion_service.active_states = _previous_active_states.duplicate(true)
	while StatsManager.emotion_service.is_blocked():
		StatsManager.emotion_service.unblock()
	if _previous_emotions_blocked:
		StatsManager.emotion_service.block()


func _make_effect(emotion: String) -> ItemEffectForceEmotion:
	var e := ItemEffectForceEmotion.new()
	e.emotion_name = emotion
	return e


func test_agrega_la_emocion_al_active_states() -> void:
	_make_effect("happy").apply(save)
	assert_true("happy" in StatsManager.emotion_service.active_states)


func test_no_limpia_otras_emociones_activas() -> void:
	StatsManager.emotion_service.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}
	_make_effect("sick").apply(save)
	assert_true("hungry" in StatsManager.emotion_service.active_states)
	assert_true("sick" in StatsManager.emotion_service.active_states)


func test_no_agrega_si_las_emociones_estan_bloqueadas() -> void:
	StatsManager.emotion_service.block()
	_make_effect("happy").apply(save)
	assert_false("happy" in StatsManager.emotion_service.active_states)


func test_guard_emotion_name_vacio_no_agrega_nada() -> void:
	_make_effect("").apply(save)
	assert_eq(StatsManager.emotion_service.active_states.size(), 0)


func test_no_sobreescribe_emocion_ya_activa() -> void:
	StatsManager.emotion_service.active_states["hungry"] = {"hour": 5.0, "stat_value": 50.0}
	_make_effect("hungry").apply(save)
	assert_eq(StatsManager.emotion_service.active_states["hungry"]["hour"], 5.0)


func test_vaciador_de_estomago_maximiza_hambre_y_fuerza_la_emocion() -> void:
	save.hambre = 10
	VACIADOR_ESTOMAGO.apply_effects(save)
	assert_eq(save.hambre, 100)
	assert_true("hungry" in StatsManager.emotion_service.active_states)
