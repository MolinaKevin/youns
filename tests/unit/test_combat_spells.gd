extends "res://tests/helpers/combat_test_case.gd"

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")
const BoardFixture := preload("res://tests/helpers/combat_board_fixture.gd")

func _map_for_modules():
	return BoardFixture.empty_modules_map()

## Hechizos, estados y charcos combinados.

func test_set_enemy_status_respeta_la_resistencia() -> void:
	var s := CombatState.new()
	s.enemy_status_reduction = 1
	assert_eq(s.set_enemy_status("blind", 3), 2)
	assert_eq(s.enemy_blinded_turns, 2)
	assert_eq(s.set_enemy_status("inexistente", 3), 0)


func test_curar_no_pasa_el_maximo() -> void:
	var s := CombatState.new()
	s.player_max_hp = 200
	s.player_hp = 150
	assert_eq(s.heal_player(80), 50)
	assert_eq(s.player_hp, 200)


func test_chispa_convierte_grasa_en_fuego_y_escarcha_agua_en_hielo() -> void:
	var map = _map_for_modules()
	map.placement.puddles.place_puddle(Vector2(10, 10), 1.0, "grease")
	map.placement.puddles.place_puddle(Vector2(20, 10), 1.0, "wet")
	assert_eq(map.effects.convert_puddles(Vector2(10, 10), 1.0, ["grease", "vine"], "fire"), 1)
	assert_eq(map.effects.convert_puddles(Vector2(20, 10), 1.0, ["wet"], "ice"), 1)
	var effects: Array = map.effects.puddles().map(func(z): return z["effect"])
	assert_eq(effects, ["fire", "ice"])
	map.free()


func test_descarga_se_propaga_por_el_agua() -> void:
	var map = _map_for_modules()
	map.enemy_pos = Vector2(10, 25)
	map.placement.puddles.place_puddle(Vector2(10, 22), 3.5, "wet")  # el enemigo está parado en el agua
	var water: Array = map.effects.puddles_on_segment(Vector2(2, 20), Vector2(14, 20), ["wet"])
	assert_eq(water.size(), 1)
	assert_true(CombatMapQueries.is_pos_in_zones(map.enemy_pos, water))
	assert_false(map.queries.areas.segment_hits_enemy(Vector2(2, 20), Vector2(14, 20)))
	map.free()


func test_aliento_alcanza_en_cono() -> void:
	var map = _map_for_modules()
	map.enemy_pos = Vector2(6, 16)
	assert_true(map.queries.areas.is_enemy_in_cone(map.player_pos, Vector2.RIGHT, 5.0, 30.0))
	assert_false(map.queries.areas.is_enemy_in_cone(map.player_pos, Vector2.LEFT, 5.0, 30.0))
	assert_false(map.queries.areas.is_enemy_in_cone(map.player_pos, Vector2.RIGHT, 2.0, 30.0))
	map.free()


func test_meteoro_cae_al_resolver_y_le_pega_a_quien_siga_ahi() -> void:
	var map = _map_for_modules()
	map.effects.delayed.place_delayed_zone(map.enemy_pos, 1.5, 120, "Meteoro")
	map.effects.delayed.place_delayed_zone(Vector2(15, 5), 1.5, 120, "Meteoro")
	var hits: Array = map.effects.delayed.resolve_delayed_zones()
	assert_eq(hits.size(), 2)
	assert_true(hits[0]["enemy"])
	assert_false(hits[1]["enemy"])
	assert_true(map.effects.delayed.delayed_zones().is_empty())
	map.free()


func test_hechizo_retardado_cae_a_las_2_rondas_y_deja_su_charco() -> void:
	var map = _map_for_modules()
	map.effects.delayed.place_delayed_zone(map.enemy_pos, 1.5, 120, "Meteoro", 2, "fire", 3)
	assert_true(map.effects.delayed.resolve_delayed_zones().is_empty())  # falta una ronda
	assert_eq(map.effects.delayed.delayed_zones().size(), 1)
	assert_true(map.effects.puddle_port.queries.puddles().is_empty())
	var hits: Array = map.effects.delayed.resolve_delayed_zones()
	assert_eq(hits.size(), 1)
	assert_true(hits[0]["enemy"])
	assert_eq(hits[0]["tick_damage"], 30)  # 25 % del daño
	assert_eq(map.effects.puddle_port.queries.puddles().size(), 1)
	assert_eq(map.effects.puddle_port.queries.puddles()[0]["effect"], "fire")
	assert_eq(map.effects.puddle_port.queries.puddles()[0]["turns"], 3)
	assert_eq(map.effects.puddle_port.queries.puddles()[0]["damage"], 30)
	map.free()


func test_hechizo_retardado_sin_efecto_no_deja_charco() -> void:
	var map = _map_for_modules()
	map.effects.delayed.place_delayed_zone(map.enemy_pos, 1.5, 50, "Test")
	map.effects.delayed.resolve_delayed_zones()
	assert_true(map.effects.puddle_port.queries.puddles().is_empty())
	map.free()


func test_impacto_de_charco_aplica_su_estado_y_danio_por_turno() -> void:
	var s := CombatState.new()
	assert_eq(CombatZoneEffectResolver.new().apply_direct_impact(s, "fire", 30, false), ["burn", 3])
	assert_eq(s.enemy_burn_damage, 30)
	assert_eq(CombatZoneEffectResolver.new().apply_direct_impact(s, "ice", 0, true), ["freeze", 2])
	assert_eq(s.player_frozen_turns, 2)
	assert_eq(CombatZoneEffectResolver.new().apply_direct_impact(s, "dark_smoke", 0, false), [])


func test_parpadeo_no_aparece_en_obstaculos_ni_encima_del_enemigo() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(10, 15), 1)
	assert_false(map.terrain.geometry.collision.can_blink_to(Vector2(10, 15)))
	assert_false(map.terrain.geometry.collision.can_blink_to(map.enemy_pos))
	assert_true(map.terrain.geometry.collision.can_blink_to(Vector2(10, 5)))
	map.effects.delayed.blink_player_to(Vector2(10, 5))
	assert_eq(map.player_pos, Vector2(10, 5))
	map.free()


func test_trasladar_charco_conserva_efecto_rondas_y_danio() -> void:
	var map = _map_for_modules()
	map.placement.puddles.place_puddle(Vector2(10, 10), 1.0, "fire", 2, 45)
	var moved: Dictionary = map.effects.puddle_port.mutation.move_puddle(map.effects.puddle_port.queries.puddle_at(Vector2(10, 10)), Vector2(20, 12))
	assert_eq(map.effects.puddle_port.queries.puddles().size(), 1)
	assert_eq(moved["pos"], Vector2(20, 12))
	assert_eq(moved["effect"], "fire")
	assert_eq(moved["turns"], 2)
	assert_eq(moved["damage"], 45)
	assert_eq(map.effects.puddle_port.queries.puddle_visual_count(), 1)
	map.free()


func test_trasladar_charco_se_lleva_su_zona_combinada() -> void:
	var map = _map_for_modules()
	map.placement.puddles.place_puddle(Vector2(10, 10), 1.0, "blood", 0, 20)
	map.placement.puddles.place_puddle(Vector2(11, 10), 1.0, "ice")
	assert_eq(map.effects.puddle_port.queries.puddles().size(), 3)  # sangre, lente de hielo sangriento, hielo
	map.effects.puddle_port.mutation.move_puddle(map.effects.puddle_port.queries.puddle_at(Vector2(11.8, 10)), Vector2(20, 20))
	var effects: Array = map.effects.puddle_port.queries.puddles().map(func(z): return z["effect"])
	assert_eq(effects, ["blood", "ice"])
	assert_true(map.effects.puddle_port.queries.puddles()[0]["excl"].is_empty())
	map.free()


func test_las_zonas_combinadas_no_se_pueden_elegir_para_trasladar() -> void:
	var map = _map_for_modules()
	map.placement.puddles.place_puddle(Vector2(10, 10), 1.0, "blood")
	map.placement.puddles.place_puddle(Vector2(11, 10), 1.0, "ice")
	var zone: Dictionary = map.effects.puddle_port.queries.puddle_at(Vector2(10.5, 10))
	assert_false(zone.get("lens", false))
	map.free()


func test_set_enemy_status_sangrado() -> void:
	var s := CombatState.new()
	assert_eq(s.set_enemy_status("bleed", 4), 4)
	assert_eq(s.enemy_bleeding_turns, 4)
