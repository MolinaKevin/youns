extends GutTest

var save: PlayerSaveData

func before_each() -> void:
	save = PlayerSaveData.new()
	GameState.player_save = save
	StatsManager.active_states.clear()
	StatsManager._emotion_block_count = 0


func _make_effect(emotion: String) -> ItemEffectForceEmotion:
	var e := ItemEffectForceEmotion.new()
	e.emotion_name = emotion
	return e


func test_agrega_la_emocion_al_active_states() -> void:
	_make_effect("happy").apply(save)
	assert_true("happy" in StatsManager.active_states)


func test_no_limpia_otras_emociones_activas() -> void:
	StatsManager.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}
	_make_effect("sick").apply(save)
	assert_true("hungry" in StatsManager.active_states)
	assert_true("sick" in StatsManager.active_states)


func test_no_agrega_si_las_emociones_estan_bloqueadas() -> void:
	StatsManager.block_emotions()
	_make_effect("happy").apply(save)
	assert_false("happy" in StatsManager.active_states)


func test_guard_emotion_name_vacio_no_agrega_nada() -> void:
	_make_effect("").apply(save)
	assert_eq(StatsManager.active_states.size(), 0)


func test_no_sobreescribe_emocion_ya_activa() -> void:
	StatsManager.active_states["hungry"] = {"hour": 5.0, "stat_value": 50.0}
	_make_effect("hungry").apply(save)
	assert_eq(StatsManager.active_states["hungry"]["hour"], 5.0)
