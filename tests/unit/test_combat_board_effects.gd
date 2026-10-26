extends "res://tests/helpers/combat_test_case.gd"

## Pruebas de charcos, módulos, árboles, hechizos y reglas del terreno.

# ── Charcos en el mapa: duración ─────────────────────────────────────────────

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")


# ── Charcos: impacto sobre actores ───────────────────────────────────────────

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
	map.place_puddle(Vector2(5, 5), 1.0, "fire", 2, 40)
	map.place_puddle(Vector2(15, 15), 1.0, "wet")  # sin duración
	map.tick_puddles()
	assert_eq(map.interactions.puddles().size(), 2)
	map.tick_puddles()
	assert_eq(map.interactions.puddles().size(), 1)
	assert_eq(map.interactions.puddles()[0]["effect"], "wet")
	assert_eq(map.interactions.puddle_visual_count(), 1)
	map.free()


func test_lente_dura_lo_que_el_charco_mas_corto() -> void:
	var map = MapAreaScript.new()
	map.place_puddle(Vector2(5, 5), 1.0, "blood", 3, 20)
	map.place_puddle(Vector2(6, 5), 1.0, "ice", 1)
	var lens: Dictionary = map.interactions.puddles().filter(func(z): return z["lens"])[0]
	assert_eq(lens["effect"], "bloody_ice")
	assert_eq(lens["turns"], 1)
	assert_eq(lens["damage"], 20)
	map.tick_puddles()
	assert_eq(map.interactions.puddles().size(), 1)
	assert_eq(map.interactions.puddles()[0]["effect"], "blood")
	assert_true(map.interactions.puddles()[0]["excl"].is_empty())
	map.free()


func test_arrastre_acerca_al_enemigo_sin_pasarse() -> void:
	var map = MapAreaScript.new()
	map.enemy_pos = Vector2(2, 2)
	assert_eq(map.calculate_drag_landing(Vector2(2, 10), 3.0), Vector2(2, 5))
	assert_eq(map.calculate_drag_landing(Vector2(2, 10), 20.0), Vector2(2, 10))
	map.free()


func test_arrastre_se_frena_en_un_obstaculo() -> void:
	var map = MapAreaScript.new()
	map.enemy_pos = Vector2(14, 25)  # al sur del obstáculo sólido de (14, 19), radio 1,5
	var landing: Vector2 = map.calculate_drag_landing(Vector2(14, 12), 20.0)
	assert_gt(landing.y, 20.5)
	map.free()


func test_romper_modulo_libera_el_paso() -> void:
	var map = MapAreaScript.new()
	var rock: Dictionary = map.get_module_at(Vector2(15.0, 15.0))
	assert_eq(rock.get("type"), "rock")
	assert_true(map.terrain.is_blocked(Vector2(15.0, 15.0)))
	assert_eq(map.break_modules(rock, 1), 1)
	assert_false(map.terrain.is_blocked(Vector2(15.0, 15.0)))
	assert_true(map.get_module_at(Vector2(15.0, 15.0)).is_empty())
	map.free()


func test_paredes_puentes_y_plataformas_no_son_modulos() -> void:
	var map = MapAreaScript.new()
	assert_true(map.get_module_at(Vector2(14.0, 19.0)).is_empty())  # pared
	assert_true(map.get_module_at(Vector2(13.0, 24.0)).is_empty())  # puente
	assert_true(map.get_module_at(Vector2(8.0, 10.0)).is_empty())   # plataforma
	map.free()


func _map_for_modules():
	var map = MapAreaScript.new()
	map.solid_obstacles.clear()  # mapa vacío para ubicar los módulos a mano
	map.player_pos = Vector2(2, 15)
	map.enemy_pos = Vector2(28, 15)
	return map


func test_muro_levanta_modulos_en_fila_perpendicular() -> void:
	var map = _map_for_modules()
	assert_eq(map.build_modules(Vector2(10, 15), 3), 3)
	var ys := []
	for obs in map.solid_obstacles:
		assert_eq(obs["pos"].x, 10.0)
		ys.append(obs["pos"].y)
	ys.sort()
	assert_eq(ys, [14.0, 15.0, 16.0])
	assert_true(map.terrain.is_blocked(Vector2(10, 15)))
	map.free()


func test_muro_no_se_levanta_encima_de_un_actor() -> void:
	var map = _map_for_modules()
	assert_eq(map.build_modules(Vector2(28, 15), 1), 0)
	map.free()


func test_romper_varios_modulos_pegados() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 3)
	map.build_modules(Vector2(20, 15), 1)  # lejos: no está pegado
	var middle: Dictionary = map.get_module_at(Vector2(10, 15))
	assert_eq(map.break_modules(middle, 5), 3)
	assert_eq(map.solid_obstacles.size(), 1)
	map.free()


func test_golpear_modulo_choca_al_enemigo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.solid_obstacles[0]
	var result: Dictionary = map.slide_module(module, Vector2.RIGHT, 30.0)
	assert_eq(result["hit"], "enemy")
	assert_lt(result["pos"].x, 28.0 - map.actors.enemy_radius())
	map.free()


func test_golpear_modulo_sin_choque_recorre_su_distancia() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	var result: Dictionary = map.slide_module(map.solid_obstacles[0], Vector2.RIGHT, 5.0)
	assert_eq(result["hit"], "")
	assert_almost_eq(result["pos"].x, 15.0, 0.001)
	map.free()


func test_golpear_modulo_se_frena_en_otro_obstaculo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.solid_obstacles[0]
	map.build_modules(Vector2(14, 15), 1)
	var result: Dictionary = map.slide_module(module, Vector2.RIGHT, 10.0)
	assert_eq(result["hit"], "")
	assert_lt(result["pos"].x, 13.0 + 0.001)
	map.free()


func test_derrumbe_tira_solo_los_modulos_pegados_al_enemigo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(26.6, 15), 1)  # pegado al enemigo (28, 15)
	map.build_modules(Vector2(28, 13.6), 1)  # pegado
	map.build_modules(Vector2(24, 15), 1)    # lejos
	assert_eq(map.modules_adjacent_to_enemy().size(), 2)
	assert_eq(map.collapse_modules_on_enemy(), 2)
	assert_eq(map.solid_obstacles.size(), 1)
	map.free()


func test_muro_que_pasa_por_encima_del_enemigo_queda_pegado_para_derrumbe() -> void:
	var map = _map_for_modules()
	map.player_pos = Vector2(28, 25)
	# Muro de 5 que cruza al enemigo (28, 15): los del medio se saltean.
	map.build_modules(Vector2(28.5, 15), 5)
	assert_lt(map.solid_obstacles.size(), 5)
	assert_eq(map.modules_adjacent_to_enemy().size(), 2)
	map.free()


func test_lanzar_modulo_le_cae_al_enemigo_y_se_rompe() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(4, 15), 1)
	var module: Dictionary = map.solid_obstacles[0]
	var hits: Dictionary = map.throw_module(module, Vector2(27.5, 15))
	assert_true(hits["enemy"])
	assert_false(hits["player"])
	assert_true(map.solid_obstacles.is_empty())
	map.free()


func test_lanzar_modulo_al_vacio_no_le_pega_a_nadie() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(4, 15), 1)
	var hits: Dictionary = map.throw_module(map.solid_obstacles[0], Vector2(15, 5))
	assert_false(hits["enemy"])
	assert_false(hits["player"])
	map.free()


# ── Hechizos ──────────────────────────────────────────────────────────────────

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
	map.place_puddle(Vector2(10, 10), 1.0, "grease")
	map.place_puddle(Vector2(20, 10), 1.0, "wet")
	assert_eq(map.convert_puddles(Vector2(10, 10), 1.0, ["grease", "vine"], "fire"), 1)
	assert_eq(map.convert_puddles(Vector2(20, 10), 1.0, ["wet"], "ice"), 1)
	var effects: Array = map.interactions.puddles().map(func(z): return z["effect"])
	assert_eq(effects, ["fire", "ice"])
	map.free()


func test_descarga_se_propaga_por_el_agua() -> void:
	var map = _map_for_modules()
	map.enemy_pos = Vector2(10, 25)
	map.place_puddle(Vector2(10, 22), 3.5, "wet")  # el enemigo está parado en el agua
	var water: Array = map.puddles_on_segment(Vector2(2, 20), Vector2(14, 20), ["wet"])
	assert_eq(water.size(), 1)
	assert_true(MapArea.is_pos_in_zones(map.enemy_pos, water))
	assert_false(map.segment_hits_enemy(Vector2(2, 20), Vector2(14, 20)))
	map.free()


func test_aliento_alcanza_en_cono() -> void:
	var map = _map_for_modules()
	map.enemy_pos = Vector2(6, 16)
	assert_true(map.is_enemy_in_cone(map.player_pos, Vector2.RIGHT, 5.0, 30.0))
	assert_false(map.is_enemy_in_cone(map.player_pos, Vector2.LEFT, 5.0, 30.0))
	assert_false(map.is_enemy_in_cone(map.player_pos, Vector2.RIGHT, 2.0, 30.0))
	map.free()


func test_meteoro_cae_al_resolver_y_le_pega_a_quien_siga_ahi() -> void:
	var map = _map_for_modules()
	map.place_delayed_zone(map.enemy_pos, 1.5, 120, "Meteoro")
	map.place_delayed_zone(Vector2(15, 5), 1.5, 120, "Meteoro")
	var hits: Array = map.resolve_delayed_zones()
	assert_eq(hits.size(), 2)
	assert_true(hits[0]["enemy"])
	assert_false(hits[1]["enemy"])
	assert_true(map.delayed_zones.is_empty())
	map.free()


func test_hechizo_retardado_cae_a_las_2_rondas_y_deja_su_charco() -> void:
	var map = _map_for_modules()
	map.place_delayed_zone(map.enemy_pos, 1.5, 120, "Meteoro", 2, "fire", 3)
	assert_true(map.resolve_delayed_zones().is_empty())  # falta una ronda
	assert_eq(map.delayed_zones.size(), 1)
	assert_true(map.interactions.puddles().is_empty())
	var hits: Array = map.resolve_delayed_zones()
	assert_eq(hits.size(), 1)
	assert_true(hits[0]["enemy"])
	assert_eq(hits[0]["tick_damage"], 30)  # 25 % del daño
	assert_eq(map.interactions.puddles().size(), 1)
	assert_eq(map.interactions.puddles()[0]["effect"], "fire")
	assert_eq(map.interactions.puddles()[0]["turns"], 3)
	assert_eq(map.interactions.puddles()[0]["damage"], 30)
	map.free()


func test_hechizo_retardado_sin_efecto_no_deja_charco() -> void:
	var map = _map_for_modules()
	map.place_delayed_zone(map.enemy_pos, 1.5, 50, "Test")
	map.resolve_delayed_zones()
	assert_true(map.interactions.puddles().is_empty())
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
	map.build_modules(Vector2(10, 15), 1)
	assert_false(map.can_blink_to(Vector2(10, 15)))
	assert_false(map.can_blink_to(map.enemy_pos))
	assert_true(map.can_blink_to(Vector2(10, 5)))
	map.blink_player_to(Vector2(10, 5))
	assert_eq(map.player_pos, Vector2(10, 5))
	map.free()


func test_trasladar_charco_conserva_efecto_rondas_y_danio() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "fire", 2, 45)
	var moved: Dictionary = map.interactions.move_puddle(map.interactions.puddle_at(Vector2(10, 10)), Vector2(20, 12))
	assert_eq(map.interactions.puddles().size(), 1)
	assert_eq(moved["pos"], Vector2(20, 12))
	assert_eq(moved["effect"], "fire")
	assert_eq(moved["turns"], 2)
	assert_eq(moved["damage"], 45)
	assert_eq(map.interactions.puddle_visual_count(), 1)
	map.free()


func test_trasladar_charco_se_lleva_su_zona_combinada() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "blood", 0, 20)
	map.place_puddle(Vector2(11, 10), 1.0, "ice")
	assert_eq(map.interactions.puddles().size(), 3)  # sangre, lente de hielo sangriento, hielo
	map.interactions.move_puddle(map.interactions.puddle_at(Vector2(11.8, 10)), Vector2(20, 20))
	var effects: Array = map.interactions.puddles().map(func(z): return z["effect"])
	assert_eq(effects, ["blood", "ice"])
	assert_true(map.interactions.puddles()[0]["excl"].is_empty())
	map.free()


func test_las_zonas_combinadas_no_se_pueden_elegir_para_trasladar() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "blood")
	map.place_puddle(Vector2(11, 10), 1.0, "ice")
	var zone: Dictionary = map.get_puddle_at(Vector2(10.5, 10))
	assert_false(zone.get("lens", false))
	map.free()


func test_set_enemy_status_sangrado() -> void:
	var s := CombatState.new()
	assert_eq(s.set_enemy_status("bleed", 4), 4)
	assert_eq(s.enemy_bleeding_turns, 4)


# ── Trepar árbol ──────────────────────────────────────────────────────────────

func test_hay_arboles_para_trepar() -> void:
	var map = MapAreaScript.new()
	assert_eq(map.get_tree_at(Vector2(5.0, 24.0)).get("type"), "tree")
	assert_true(map.get_tree_at(Vector2(15.0, 15.0)).is_empty())  # piedra, no árbol
	assert_true(map.terrain.is_blocked(Vector2(5.0, 24.0)))
	map.free()


func test_caer_del_arbol_sobre_el_enemigo_queda_pegado_a_el() -> void:
	var map = MapAreaScript.new()
	map.player_pos = Vector2(5.0, 25.4)
	map.enemy_pos = Vector2(8.0, 24.0)
	var tree: Dictionary = map.get_tree_at(Vector2(5.0, 24.0))
	map.climb_tree(tree, map.enemy_pos)
	assert_true(map.is_player_in_tree())
	assert_true(map.drop_from_tree(map.enemy_pos))
	assert_false(map.is_player_in_tree())
	assert_almost_eq(map.player_pos.distance_to(map.enemy_pos), map.MIN_SEPARATION, 0.01)
	map.free()


func test_caer_del_arbol_en_un_lugar_libre() -> void:
	var map = MapAreaScript.new()
	map.player_pos = Vector2(5.0, 25.4)
	var tree: Dictionary = map.get_tree_at(Vector2(5.0, 24.0))
	map.climb_tree(tree, Vector2(8.0, 26.0))
	assert_false(map.drop_from_tree(Vector2(8.0, 26.0)))
	assert_eq(map.player_pos, Vector2(8.0, 26.0))
	map.free()


func test_arriba_del_arbol_el_enemigo_no_te_alcanza() -> void:
	var s := CombatState.new()
	s.player_in_tree = true
	_map.enemy_pos = Vector2(1.0, 0.0)
	var card := _make_monster_card(20, [_make_monster_action("attack", 2)])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	var hp := s.player_hp
	await ai.execute_card(card)
	assert_eq(s.player_hp, hp)


func test_arriba_del_arbol_no_te_podes_mover() -> void:
	var s := CombatState.new()
	s.player_in_tree = true
	s.turn_actions.append(_make_card("move"))
	var pa := _make_player_actions(s)
	pa.play_card(0)
	assert_false(pa.has_pending_selection())
	assert_eq(_map.start_move_selection_calls, 0)


func _map_with_tree(tree_pos := Vector2(10, 15)):
	var map = _map_for_modules()
	map.solid_obstacles.append({"pos": tree_pos, "radius": 0.6, "type": "tree"})
	return map


func test_talar_arbol_deja_un_tronco_tirado() -> void:
	var map = _map_with_tree()
	var tree: Dictionary = map.get_tree_at(Vector2(10, 15))
	var result: Dictionary = map.fell_tree(tree, Vector2.RIGHT)
	assert_false(result["enemy_hit"])
	assert_true(map.get_tree_at(Vector2(10, 15)).is_empty())
	var segments: Array = map.solid_obstacles.filter(func(o): return o.has("log_id"))
	assert_eq(segments.size(), map.LOG_SEGMENTS)
	assert_true(map.terrain.is_blocked(Vector2(10.9, 15)))
	assert_true(map.has_line_of_sight(Vector2(10.9, 13), Vector2(10.9, 17)))  # es bajo: se ve por encima
	map.free()


func test_el_tronco_se_rompe_entero_con_una_carta() -> void:
	var map = _map_with_tree()
	map.fell_tree(map.get_tree_at(Vector2(10, 15)), Vector2.RIGHT)
	var piece: Dictionary = map.get_module_at(Vector2(10.9, 15))
	assert_eq(map.break_modules(piece, 1), map.LOG_SEGMENTS)
	assert_true(map.solid_obstacles.is_empty())
	map.free()


func test_arbol_que_cae_sobre_el_enemigo_le_pega() -> void:
	var map = _map_with_tree(Vector2(26.2, 15))
	var result: Dictionary = map.fell_tree(map.get_tree_at(Vector2(26.2, 15)), Vector2.RIGHT)
	assert_true(result["enemy_hit"])
	map.free()


func test_talar_el_arbol_con_el_jugador_arriba_lo_tira() -> void:
	var map = _map_with_tree()
	var knocked := []
	map.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	map.climb_tree(map.get_tree_at(Vector2(10, 15)), Vector2(12, 12))
	map.fell_tree(map.get_tree_at(Vector2(10, 15)), Vector2.RIGHT)
	assert_eq(knocked, [false])
	assert_false(map.is_player_in_tree())
	map.free()


func test_charco_de_fuego_prende_el_arbol_y_se_consume() -> void:
	var map = _map_with_tree()
	var knocked := []
	map.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	var tree: Dictionary = map.get_tree_at(Vector2(10, 15))
	map.climb_tree(tree, Vector2(12, 12))
	map.place_puddle(Vector2(10.5, 16), 1.0, "fire", 3, 30)
	assert_true(MapArea.is_tree_burning(tree))
	assert_eq(knocked, [true])
	map.tick_trees()
	assert_false(map.get_tree_at(Vector2(10, 15)).is_empty())
	map.tick_trees()
	assert_true(map.get_tree_at(Vector2(10, 15)).is_empty())
	map.free()


func test_otros_charcos_no_prenden_arboles() -> void:
	var map = _map_with_tree()
	map.place_puddle(Vector2(10.5, 16), 1.0, "wet")
	assert_false(MapArea.is_tree_burning(map.get_tree_at(Vector2(10, 15))))
	map.free()


func test_golpear_un_modulo_contra_el_arbol_tira_al_de_arriba() -> void:
	var map = _map_with_tree(Vector2(14, 15))
	var knocked := []
	map.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	map.climb_tree(map.get_tree_at(Vector2(14, 15)), Vector2(12, 12))
	map.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.get_module_at(Vector2(10, 15))
	var result: Dictionary = map.slide_module(module, Vector2.RIGHT, 10.0)
	assert_false(result["tree"].is_empty())
	assert_eq(knocked, [false])
	map.free()


func test_agua_y_hielo_apagan_arboles_en_llamas() -> void:
	var map = _map_with_tree()
	var tree: Dictionary = map.get_tree_at(Vector2(10, 15))
	map.ignite_trees_in_circle(Vector2(10, 15), 1.0)
	assert_true(MapArea.is_tree_burning(tree))
	map.place_puddle(Vector2(10.5, 16), 1.0, "wet")
	assert_false(MapArea.is_tree_burning(tree))
	map.ignite_trees_in_circle(Vector2(10, 15), 1.0)
	assert_eq(map.extinguish_trees_in_circle(Vector2(10, 15), 1.0), 1)
	map.free()


func test_el_rayo_se_frena_en_el_primer_arbol() -> void:
	var map = _map_with_tree(Vector2(8, 15))
	var rod: Dictionary = map.first_tree_on_segment(Vector2(2, 15), Vector2(20, 15))
	assert_false(rod.is_empty())
	assert_lt(rod["t"], 0.5)
	assert_true(map.first_tree_on_segment(Vector2(2, 10), Vector2(20, 10)).is_empty())
	map.free()


func test_charco_de_planta_junto_a_un_arbol_es_mas_grande() -> void:
	var map = _map_with_tree()
	map.place_puddle(Vector2(11.5, 15), 1.0, "vine")
	map.place_puddle(Vector2(25, 5), 1.0, "vine")
	assert_almost_eq(float(map.interactions.puddles()[0]["radius"]), 1.0 * map.TREE_VINE_RADIUS_MULT, 0.001)
	assert_almost_eq(float(map.interactions.puddles()[1]["radius"]), 1.0, 0.001)
	map.free()


func test_el_fuego_del_arbol_se_propaga_por_la_planta_a_otro_arbol() -> void:
	var map = _map_with_tree(Vector2(10, 15))
	map.solid_obstacles.append({"pos": Vector2(13, 15), "radius": 0.6, "type": "tree"})
	map.place_puddle(Vector2(11.5, 15), 1.0, "vine")  # une los dos árboles
	map.ignite_trees_in_circle(Vector2(10, 15), 0.5)
	assert_eq(map.interactions.puddles()[0]["effect"], "fire")
	assert_true(MapArea.is_tree_burning(map.get_tree_at(Vector2(13, 15))))
	map.free()


func test_ariete_empuja_el_tronco_entero() -> void:
	var map = _map_with_tree(Vector2(10, 10))
	map.fell_tree(map.get_tree_at(Vector2(10, 10)), Vector2.RIGHT)
	var before: Array = map.solid_obstacles.map(func(o): return o["pos"])
	map.slide_module(map.get_module_at(Vector2(10, 10)), Vector2.DOWN, 3.0)
	var after: Array = map.solid_obstacles.map(func(o): return o["pos"])
	for i in before.size():
		assert_almost_eq((after[i] - before[i]).y, 3.0, 0.001)
		assert_almost_eq((after[i] - before[i]).x, 0.0, 0.001)
	map.free()


func test_caer_del_arbol_en_un_charco_te_aplica_su_efecto() -> void:
	var s := CombatState.new()
	s.player_in_tree = true
	_map.puddle_effects_result = {"poison": true}
	_map.puddle_damage_result = {"poison": 14}
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, Callable(), _dmg_player_callable(s), func() -> bool: return false)
	await pa.player_falls_from_tree(false)
	assert_gt(s.player_poison_stacks, 0)
	assert_eq(s.player_poison_damage, 14)


func test_confirmar_deja_fija_la_vista_previa_en_el_clic() -> void:
	var map = MapAreaScript.new()
	map.lock_hover_at_last_click()
	assert_true(map.is_hover_locked())
	map.unlock_hover()
	assert_false(map.is_hover_locked())
	map.free()


func test_cancelar_cierra_el_popup_de_confirmar() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	var hidden := [0]
	pa.confirm_popup_hide_requested.connect(func(): hidden[0] += 1)
	pa.pending_cell = Vector2(3, 3)
	pa.cancel_selection()
	assert_eq(hidden[0], 1)
	assert_eq(pa.pending_cell, Vector2(-1, -1))


func test_caerse_de_un_arbol_en_llamas_hace_danio_y_prende_fuego() -> void:
	var s := CombatState.new()
	s.player_in_tree = true
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, Callable(), _dmg_player_callable(s), func() -> bool: return false)
	var hp := s.player_hp
	await pa.player_falls_from_tree(true)
	assert_false(s.player_in_tree)
	assert_eq(s.player_hp, hp - CombatPlayerActions.TREE_FALL_DAMAGE)
	assert_gt(s.player_burning_turns, 0)


func test_charcos_cuestan_mp() -> void:
	for card: CardData in CardDatabase.cards_by_id.values():
		for line: CardActionLine in card.top.lines + card.bottom.lines:
			if line.card_type == "puddle":
				assert_gt(line.mp_cost, 0, card.id)


func test_danio_de_charco_a_lo_largo_de_un_segmento() -> void:
	var map = MapAreaScript.new()
	map.place_puddle(Vector2(5, 5), 1.0, "fire", 3, 40)
	map.place_puddle(Vector2(5, 5), 1.0, "wet")
	assert_eq(map.interactions.puddle_damage_along(Vector2(3, 5), Vector2(7, 5)), {"fire": 40})
	assert_eq(map.interactions.puddle_damage_along(Vector2(20, 20), Vector2(21, 20)), {})
	map.free()


func test_areas_exigen_contacto_de_un_tercio_de_la_huella() -> void:
	var map = _map_for_modules()
	map.actors.set_enemy_radius(0.3)
	map.enemy_pos = Vector2(11.09, 10.0) # radio 1 + margen de área 0,1
	assert_true(map.is_enemy_in_area_circle(Vector2(10, 10), 1.0))
	map.enemy_pos = Vector2(11.11, 10.0)
	assert_false(map.is_enemy_in_area_circle(Vector2(10, 10), 1.0))
	# La conversión de charcos conserva su intersección propia, sin este umbral.
	map.place_puddle(Vector2(12.0, 10.0), 1.0, "grease")
	assert_eq(map.convert_puddles(Vector2(10, 10), 1.0, ["grease"], "fire"), 1)
	map.free()
