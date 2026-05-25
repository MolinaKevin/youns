extends GutTest

var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()
	GameState.player_save = save
	StatsManager.active_states.clear()
	StatsManager._emotion_block_count = 0


# ── ItemEffectEvolve — pending_evolution_path ─────────────────────────────────

func test_evolve_setea_pending_evolution_path() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/pombero.tres"
	effect.apply(save)
	assert_eq(save.pending_evolution_path, "res://data/youns/pombero.tres")


func test_evolve_con_path_vacio_no_muta_save() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = ""
	effect.apply(save)
	assert_eq(save.pending_evolution_path, "")


func test_evolve_sobreescribe_evolucion_pendiente_anterior() -> void:
	save.pending_evolution_path = "res://data/youns/pombero.tres"
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/nguruvilu.tres"
	effect.apply(save)
	assert_eq(save.pending_evolution_path, "res://data/youns/nguruvilu.tres")


# ── ItemEffectEvolve — emoción evolving ───────────────────────────────────────

func test_evolve_activa_emocion_evolving() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/pombero.tres"
	effect.apply(save)
	assert_true(StatsManager.active_states.has("evolving"))


func test_evolve_guarda_target_youn_path_en_active_states() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/pombero.tres"
	effect.apply(save)
	assert_eq(StatsManager.active_states["evolving"].get("target_youn_path"), "res://data/youns/pombero.tres")


func test_evolve_nguruvilu_guarda_su_propio_target_en_active_states() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/nguruvilu.tres"
	effect.apply(save)
	assert_eq(StatsManager.active_states["evolving"].get("target_youn_path"), "res://data/youns/nguruvilu.tres")


func test_evolve_limpia_emociones_previas() -> void:
	StatsManager.active_states["happy"] = {"hour": 0.0, "stat_value": 100.0}
	StatsManager.active_states["tired"] = {"hour": 0.0, "stat_value": 50.0}
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/pombero.tres"
	effect.apply(save)
	assert_false(StatsManager.active_states.has("happy"))
	assert_false(StatsManager.active_states.has("tired"))


func test_evolve_bloquea_nuevas_emociones() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/pombero.tres"
	effect.apply(save)
	StatsManager.show_emotion("happy")
	assert_false(StatsManager.active_states.has("happy"))


func test_evolve_solo_deja_activa_la_emocion_evolving() -> void:
	var effect := ItemEffectEvolve.new()
	effect.youn_data_path = "res://data/youns/pombero.tres"
	effect.apply(save)
	assert_eq(StatsManager.active_states.size(), 1)
	assert_true(StatsManager.active_states.has("evolving"))


# ── Items concretos — efecto directo ─────────────────────────────────────────

func test_semilla_embrujada_evoluciona_a_pombero() -> void:
	var item := load("res://data/items/semilla_embrujada.tres") as ItemData
	var effect := item.effects[0] as ItemEffectEvolve
	effect.apply(save)
	assert_eq(save.pending_evolution_path, "res://data/youns/pombero.tres")


func test_brebaje_mapuche_evoluciona_a_nguruvilu() -> void:
	var item := load("res://data/items/brebaje_mapuche.tres") as ItemData
	var effect := item.effects[0] as ItemEffectEvolve
	effect.apply(save)
	assert_eq(save.pending_evolution_path, "res://data/youns/nguruvilu.tres")


# ── Items concretos — apply_effects activa emoción evolving ───────────────────

func test_dar_semilla_embrujada_activa_emocion_evolving() -> void:
	var item := load("res://data/items/semilla_embrujada.tres") as ItemData
	item.apply_effects(save)
	assert_true(StatsManager.active_states.has("evolving"))


func test_dar_brebaje_mapuche_activa_emocion_evolving() -> void:
	var item := load("res://data/items/brebaje_mapuche.tres") as ItemData
	item.apply_effects(save)
	assert_true(StatsManager.active_states.has("evolving"))


func test_dar_semilla_embrujada_bloquea_otras_emociones() -> void:
	var item := load("res://data/items/semilla_embrujada.tres") as ItemData
	item.apply_effects(save)
	StatsManager.show_emotion("happy")
	assert_false(StatsManager.active_states.has("happy"))
