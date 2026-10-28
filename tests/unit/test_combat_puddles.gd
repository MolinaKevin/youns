extends "res://tests/helpers/combat_test_case.gd"

## Contratos de charcos aislados del resto de efectos de tablero.
const MapAreaScript := preload("res://features/combat/scene/map_area.gd")

func test_enemigo_que_pisa_fuego_toma_el_danio_del_charco() -> void:
	var s := CombatState.new()
	var ai := _make_ai(s)
	_map.puddle_effects_result = {"fire": true, "poison": true}
	_map.puddle_damage_result = {"fire": 55, "poison": 14}
	ai.apply_zone_effects(Vector2.ZERO)
	assert_eq(s.enemy_burning_turns, 3)
	assert_eq(s.enemy_burn_damage, 55)
	assert_eq(s.enemy_poison_damage, 14)

func test_charco_sin_danio_propio_usa_el_danio_por_defecto() -> void:
	var s := CombatState.new()
	var ai := _make_ai(s)
	_map.puddle_effects_result = {"fire": true}
	ai.apply_zone_effects(Vector2.ZERO)
	assert_eq(s.enemy_burn_damage, CombatState.BURN_DAMAGE)

func test_charco_con_duracion_desaparece_al_pasar_sus_rondas() -> void:
	var map = MapAreaScript.new()
	map.placement.puddles.place_puddle(Vector2(5, 5), 1.0, "fire", 2, 40)
	map.placement.puddles.place_puddle(Vector2(15, 15), 1.0, "wet")
	map.effects.puddle_port.mutation.tick_puddles()
	assert_eq(map.effects.puddle_port.queries.puddles().size(), 2)
	map.effects.puddle_port.mutation.tick_puddles()
	assert_eq(map.effects.puddle_port.queries.puddles().size(), 1)
	assert_eq(map.effects.puddle_port.queries.puddles()[0]["effect"], "wet")
	assert_eq(map.effects.puddle_port.queries.puddle_visual_count(), 1)
	map.free()

func test_lente_dura_lo_que_el_charco_mas_corto() -> void:
	var map = MapAreaScript.new()
	map.placement.puddles.place_puddle(Vector2(5, 5), 1.0, "blood", 3, 20)
	map.placement.puddles.place_puddle(Vector2(6, 5), 1.0, "ice", 1)
	var lens: Dictionary = map.effects.puddle_port.queries.puddles().filter(func(z): return z["lens"])[0]
	assert_eq(lens["effect"], "bloody_ice")
	assert_eq(lens["turns"], 1)
	assert_eq(lens["damage"], 20)
	map.effects.puddle_port.mutation.tick_puddles()
	assert_eq(map.effects.puddle_port.queries.puddles().size(), 1)
	assert_eq(map.effects.puddle_port.queries.puddles()[0]["effect"], "blood")
	assert_true(map.effects.puddle_port.queries.puddles()[0]["excl"].is_empty())
	map.free()
