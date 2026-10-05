extends GutTest

# StatsManager.calc_hambre_delta(delta, mult, weight, base_weight) -> int
# aun no existe — estos tests definen el comportamiento esperado antes de implementarlo


var _youn_backup: Node


func before_each() -> void:
	GameState.player_save = PlayerSaveData.new()
	StatsManager.active_states.clear()
	_youn_backup = PartyManager.youn
	PartyManager.youn = null


func after_each() -> void:
	StatsManager.active_states.clear()
	GameState.player_save = null
	PartyManager.youn = _youn_backup


# ── on_meal_eaten ─────────────────────────────────────────────────────────────

# Cuánto sacia y cuántas ganas de baño da lo decide cada comida con sus efectos.

func test_meal_eaten_no_toca_hambre_ni_ganas_bano() -> void:
	GameState.player_save.hambre = 80
	GameState.player_save.ganas_bano = 30
	StatsManager.on_meal_eaten()
	assert_eq(GameState.player_save.hambre, 80)
	assert_eq(GameState.player_save.ganas_bano, 30)


func test_meal_eaten_limpia_emocion_hungry() -> void:
	StatsManager.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}
	StatsManager.on_meal_eaten()
	assert_false("hungry" in StatsManager.active_states)


func test_meal_eaten_registra_hora_de_comida() -> void:
	GameState.current_day = 1
	GameState.time_of_day_hours = 12.0
	StatsManager.on_meal_eaten()
	assert_almost_eq(GameState.player_save.last_meal_total_hour, GameState.get_total_hours(), 0.01)

# ── calc_hambre_delta — sin peso extra, solo multiplicador ────────────────────

func test_calc_sin_sobrepeso_mult_1_devuelve_delta() -> void:
	assert_eq(StatsManager.calc_hambre_delta(-30, 1.0, 10.0, 10.0), -30)


func test_calc_sin_sobrepeso_mult_2_duplica_delta() -> void:
	assert_eq(StatsManager.calc_hambre_delta(-30, 2.0, 10.0, 10.0), -60)


func test_calc_sin_sobrepeso_mult_05_reduce_delta() -> void:
	assert_eq(StatsManager.calc_hambre_delta(-30, 0.5, 10.0, 10.0), -15)


# ── calc_hambre_delta — con sobrepeso (delta negativo) ────────────────────────

func test_calc_10kg_sobre_reduce_efectividad_al_70_porciento() -> void:
	# mult=1.0, 10kg sobre base: 1.0 * (1.0 - 10*0.03) = 0.7
	assert_eq(StatsManager.calc_hambre_delta(-30, 1.0, 20.0, 10.0), -21)


func test_calc_sobrepeso_extremo_se_limita_al_30_porciento() -> void:
	# mult=1.0, 30kg sobre base: 1.0 - 30*0.03 = 0.1 → capped a 0.3
	assert_eq(StatsManager.calc_hambre_delta(-30, 1.0, 40.0, 10.0), -9)


func test_calc_sobrepeso_con_mult_alto() -> void:
	# mult=2.0, 10kg sobre base: 2.0 * 0.7 = 1.4
	assert_eq(StatsManager.calc_hambre_delta(-30, 2.0, 20.0, 10.0), -42)


# ── calc_hambre_delta — delta positivo ignora el peso ────────────────────────

func test_calc_delta_positivo_no_aplica_reduccion_por_peso() -> void:
	# hambre aumentando: el sobrepeso no afecta
	assert_eq(StatsManager.calc_hambre_delta(10, 1.0, 40.0, 10.0), 10)


func test_calc_delta_positivo_aplica_multiplicador() -> void:
	assert_eq(StatsManager.calc_hambre_delta(10, 2.0, 40.0, 10.0), 20)


# ── weight_gain al comer ──────────────────────────────────────────────────────

func test_comer_item_con_weight_gain_1_aumenta_1kg() -> void:
	GameState.player_save.weight = 10.0
	var item := ItemData.new()
	item.weight_gain = 1.0
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.weight, 11.0, 0.01)


func test_comer_item_con_weight_gain_15_aumenta_15kg() -> void:
	GameState.player_save.weight = 10.0
	var item := ItemData.new()
	item.weight_gain = 1.5
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.weight, 11.5, 0.01)


func test_comer_item_sin_weight_gain_no_cambia_el_peso() -> void:
	GameState.player_save.weight = 10.0
	var item := ItemData.new()
	item.weight_gain = 0.0
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.weight, 10.0, 0.01)


func test_comer_multiples_items_acumula_el_peso() -> void:
	GameState.player_save.weight = 10.0
	var item := ItemData.new()
	item.weight_gain = 1.0
	item.apply_effects(GameState.player_save)
	item.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.weight, 12.0, 0.01)


# ── comida.tres — todos los efectos ──────────────────────────────────────────

func test_comida_reduce_hambre_en_50() -> void:
	GameState.player_save.hambre = 80
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.hambre, 30)


func test_comida_sin_ganas_propias_suma_30_de_bano() -> void:
	GameState.player_save.ganas_bano = 0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.ganas_bano, ItemEffectMeal.DEFAULT_BATHROOM_GAIN)


func test_comida_ganas_bano_no_supera_100() -> void:
	GameState.player_save.ganas_bano = 90
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.ganas_bano, 100)


func test_comida_aumenta_peso_en_1kg() -> void:
	GameState.player_save.weight = 10.0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.weight, 11.0, 0.01)


func test_comida_acumula_1_de_poop_pending() -> void:
	GameState.player_save.poop_pending = 0.0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.poop_pending, 1.0, 0.01)


func test_comida_registra_la_hora_de_comida() -> void:
	GameState.current_day = 2
	GameState.time_of_day_hours = 9.0
	GameState.player_save.last_meal_total_hour = -1.0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_almost_eq(GameState.player_save.last_meal_total_hour, GameState.get_total_hours(), 0.01)


func test_efecto_meal_usa_sus_propias_ganas_de_bano() -> void:
	GameState.player_save.ganas_bano = 0
	var meal := ItemEffectMeal.new()
	meal.bathroom_gain = 55
	meal.apply(GameState.player_save)
	assert_eq(GameState.player_save.ganas_bano, 55)


func test_efecto_meal_con_bano_en_0_no_suma_ganas() -> void:
	GameState.player_save.ganas_bano = 10
	var meal := ItemEffectMeal.new()
	meal.bathroom_gain = 0
	meal.apply(GameState.player_save)
	assert_eq(GameState.player_save.ganas_bano, 10)


func test_efecto_meal_baja_el_hambre_lo_que_llena() -> void:
	GameState.player_save.hambre = 90
	var meal := ItemEffectMeal.new()
	meal.fills = 70
	meal.apply(GameState.player_save)
	assert_eq(GameState.player_save.hambre, 20)


func test_efecto_meal_limpia_emocion_hungry() -> void:
	StatsManager.active_states["hungry"] = {"hour": 0.0, "stat_value": 100.0}
	ItemEffectMeal.new().apply(GameState.player_save)
	assert_false("hungry" in StatsManager.active_states)


func test_comida_aplica_todos_los_efectos_juntos() -> void:
	GameState.player_save.hambre = 80
	GameState.player_save.ganas_bano = 0
	GameState.player_save.weight = 10.0
	GameState.player_save.poop_pending = 0.0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.hambre, 30)
	assert_eq(GameState.player_save.ganas_bano, 30)
	assert_almost_eq(GameState.player_save.weight, 11.0, 0.01)
	assert_almost_eq(GameState.player_save.poop_pending, 1.0, 0.01)


func test_efecto_meal_sube_la_salud_por_defecto() -> void:
	GameState.player_save.salud = 50
	ItemEffectMeal.new().apply(GameState.player_save)
	assert_eq(GameState.player_save.salud, 50 + ItemEffectMeal.DEFAULT_HEALTH_GAIN)


func test_efecto_meal_con_salud_propia_usa_la_suya() -> void:
	GameState.player_save.salud = 50
	var meal := ItemEffectMeal.new()
	meal.health_gain = 20
	meal.apply(GameState.player_save)
	assert_eq(GameState.player_save.salud, 70)


func test_efecto_meal_con_salud_negativa_la_baja() -> void:
	GameState.player_save.salud = 50
	var meal := ItemEffectMeal.new()
	meal.health_gain = -15
	meal.apply(GameState.player_save)
	assert_eq(GameState.player_save.salud, 35)


func test_efecto_meal_con_salud_propia_en_0_no_la_cambia() -> void:
	GameState.player_save.salud = 50
	var meal := ItemEffectMeal.new()
	meal.health_gain = 0
	meal.apply(GameState.player_save)
	assert_eq(GameState.player_save.salud, 50)


func test_dormir_recupera_salud_por_hora_con_tope() -> void:
	assert_eq(StatsManager.salud_from_sleep(0), 0)
	assert_eq(StatsManager.salud_from_sleep(3), 3 * StatsManager.SLEEP_HEALTH_PER_HOUR)
	assert_eq(StatsManager.salud_from_sleep(12),
		StatsManager.SLEEP_HEALTH_MAX_HOURS * StatsManager.SLEEP_HEALTH_PER_HOUR)
