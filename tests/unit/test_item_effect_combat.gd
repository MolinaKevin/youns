extends GutTest

# Ítems de combate (comodín "Ítem"): ItemEffectCombat actúa sobre CombatState.

var state: CombatState


func before_each() -> void:
	state = CombatState.new()
	state.player_max_hp = 200
	state.player_hp = 100
	state.player_max_mp = 90
	state.player_mp = 10


func test_hierba_curativa_cura_80() -> void:
	var item: ItemData = load("res://data/items/hierba_curativa.tres")
	var r := item.apply_in_combat(state)
	assert_eq(state.player_hp, 180)
	assert_eq(r["healed"], 80)


func test_la_curacion_no_pasa_el_maximo() -> void:
	state.player_hp = 190
	var item: ItemData = load("res://data/items/hierba_curativa.tres")
	item.apply_in_combat(state)
	assert_eq(state.player_hp, 200)


func test_agua_de_manantial_recupera_30_de_mp() -> void:
	var item: ItemData = load("res://data/items/agua_de_manantial.tres")
	item.apply_in_combat(state)
	assert_eq(state.player_mp, 40)


func test_unguento_saca_los_estados_y_cura() -> void:
	state.player_poison_stacks = 3
	state.player_burning_turns = 2
	state.player_frozen_turns = 1
	var item: ItemData = load("res://data/items/unguento.tres")
	var r := item.apply_in_combat(state)
	assert_eq(state.player_poison_stacks, 0)
	assert_eq(state.player_burning_turns, 0)
	assert_eq(state.player_frozen_turns, 0)
	assert_eq(state.player_hp, 130)
	assert_true(r["cleansed"])


func test_items_de_combate_se_reconocen() -> void:
	assert_true((load("res://data/items/hierba_curativa.tres") as ItemData).is_combat_only())
	assert_false((load("res://data/items/comida.tres") as ItemData).is_combat_item())


func test_fuera_de_combate_no_hace_nada() -> void:
	var save := PlayerSaveData.new()
	var salud := save.salud
	var item: ItemData = load("res://data/items/unguento.tres")
	for effect in item.effects:
		effect.apply(save)
	assert_eq(save.salud, salud)
