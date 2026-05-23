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

func test_meal_eaten_resetea_hambre_a_cero() -> void:
	GameState.player_save.hambre = 80
	StatsManager.on_meal_eaten()
	assert_eq(GameState.player_save.hambre, 0)


func test_meal_eaten_aumenta_ganas_bano() -> void:
	GameState.player_save.ganas_bano = 30
	StatsManager.on_meal_eaten()
	assert_eq(GameState.player_save.ganas_bano, 55)


func test_meal_eaten_ganas_bano_no_supera_100() -> void:
	GameState.player_save.ganas_bano = 90
	StatsManager.on_meal_eaten()
	assert_eq(GameState.player_save.ganas_bano, 100)


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

func test_comida_reduce_hambre_en_25() -> void:
	GameState.player_save.hambre = 80
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.hambre, 55)


func test_comida_aumenta_ganas_bano_en_70() -> void:
	GameState.player_save.ganas_bano = 0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.ganas_bano, 70)


func test_comida_ganas_bano_no_supera_100() -> void:
	GameState.player_save.ganas_bano = 60
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


func test_comida_aplica_todos_los_efectos_juntos() -> void:
	GameState.player_save.hambre = 80
	GameState.player_save.ganas_bano = 0
	GameState.player_save.weight = 10.0
	GameState.player_save.poop_pending = 0.0
	var comida: ItemData = load("res://data/items/comida.tres")
	comida.apply_effects(GameState.player_save)
	assert_eq(GameState.player_save.hambre, 55)
	assert_eq(GameState.player_save.ganas_bano, 70)
	assert_almost_eq(GameState.player_save.weight, 11.0, 0.01)
	assert_almost_eq(GameState.player_save.poop_pending, 1.0, 0.01)
