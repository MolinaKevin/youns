extends GutTest

# Asume:
# - PlayerSaveData tiene poop_pending: float
# - ItemData tiene poop_size: float
# - ItemData.apply_effects() acumula poop_size en save.poop_pending
# - StatsManager.on_bathroom_used(rng: RandomNumberGenerator = null)
#     baja el peso en poop_pending + randf()*peso*0.1, resetea poop_pending


func before_each() -> void:
	GameState.player_save = PlayerSaveData.new()
	StatsManager.active_states.clear()


func after_each() -> void:
	StatsManager.active_states.clear()
	GameState.player_save = null


# ── acumulacion de poop_pending ───────────────────────────────────────────────

func test_comer_item_con_poop_size_acumula_poop_pending() -> void:
	GameState.player_save.poop_pending = 0.0
	var item := ItemData.new()
	item.poop_size = 0.5
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.poop_pending, 0.5, 0.01)


func test_comer_multiples_items_acumula_poop_pending() -> void:
	GameState.player_save.poop_pending = 0.0
	var item := ItemData.new()
	item.poop_size = 0.5
	item.apply_effects(GameState.player_save)
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.poop_pending, 1.0, 0.01)


func test_item_sin_poop_size_no_acumula() -> void:
	GameState.player_save.poop_pending = 0.0
	var item := ItemData.new()
	item.poop_size = 0.0
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.poop_pending, 0.0, 0.01)


func test_poop_pending_acumula_sobre_valor_existente() -> void:
	GameState.player_save.poop_pending = 1.0
	var item := ItemData.new()
	item.poop_size = 0.8
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.poop_pending, 1.8, 0.01)


# ── on_bathroom_used — limites del peso perdido ───────────────────────────────

func test_bano_reduce_peso_al_menos_el_poop_pending() -> void:
	GameState.player_save.weight = 20.0
	GameState.player_save.poop_pending = 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 0  # randf() puede ser cualquier valor
	StatsManager.on_bathroom_used(rng)
	assert_lte(GameState.player_save.weight, 20.0 - 2.0)


func test_bano_no_reduce_mas_del_poop_pending_mas_10_porciento_del_peso() -> void:
	GameState.player_save.weight = 20.0
	GameState.player_save.poop_pending = 2.0
	var max_loss := 2.0 + 20.0 * 0.1  # 4.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	StatsManager.on_bathroom_used(rng)
	assert_gte(GameState.player_save.weight, 20.0 - max_loss)


func test_bano_con_seed_produce_resultado_deterministico() -> void:
	GameState.player_save.weight = 20.0
	GameState.player_save.poop_pending = 2.0

	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 42
	StatsManager.on_bathroom_used(rng1)
	var weight1 := GameState.player_save.weight

	GameState.player_save.weight = 20.0
	GameState.player_save.poop_pending = 2.0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	StatsManager.on_bathroom_used(rng2)
	var weight2 := GameState.player_save.weight

	assert_almost_eq(weight1, weight2, 0.001)


func test_bano_resetea_poop_pending() -> void:
	GameState.player_save.weight = 20.0
	GameState.player_save.poop_pending = 2.0
	StatsManager.on_bathroom_used()
	assert_almost_eq(GameState.player_save.poop_pending, 0.0, 0.001)


func test_bano_no_baja_el_peso_por_debajo_de_cero() -> void:
	GameState.player_save.weight = 0.5
	GameState.player_save.poop_pending = 5.0
	StatsManager.on_bathroom_used()
	assert_gte(GameState.player_save.weight, 0.0)
