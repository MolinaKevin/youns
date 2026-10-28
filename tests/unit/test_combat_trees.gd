extends "res://tests/helpers/combat_test_case.gd"

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")
const BoardFixture := preload("res://tests/helpers/combat_board_fixture.gd")

func _map_for_modules():
	return BoardFixture.empty_modules_map()

## Trepar, talar y propagar efectos entre árboles.

func _map_with_tree(tree_pos := Vector2(10, 15)):
	var map = _map_for_modules()
	map.solid_obstacles.append({"pos": tree_pos, "radius": 0.6, "type": "tree"})
	return map


func test_talar_arbol_deja_un_tronco_tirado() -> void:
	var map = _map_with_tree()
	var tree: Dictionary = map.obstacles.trees.queries.tree_at(Vector2(10, 15))
	var result: Dictionary = map.obstacles.trees.movement.fell_tree(tree, Vector2.RIGHT)
	assert_false(result["enemy_hit"])
	assert_true(map.obstacles.trees.queries.tree_at(Vector2(10, 15)).is_empty())
	var segments: Array = map.solid_obstacles.filter(func(o): return o.has("log_id"))
	assert_eq(segments.size(), map.LOG_SEGMENTS)
	assert_true(map.terrain.geometry.collision.is_blocked(Vector2(10.9, 15)))
	assert_true(map.queries.line_of_sight.has_line_of_sight(Vector2(10.9, 13), Vector2(10.9, 17)))  # es bajo: se ve por encima
	map.free()


func test_el_tronco_se_rompe_entero_con_una_carta() -> void:
	var map = _map_with_tree()
	map.obstacles.trees.movement.fell_tree(map.obstacles.trees.queries.tree_at(Vector2(10, 15)), Vector2.RIGHT)
	var piece: Dictionary = map.obstacles.modules.module_at(Vector2(10.9, 15))
	assert_eq(map.obstacles.modules.break_modules(piece, 1), map.LOG_SEGMENTS)
	assert_true(map.solid_obstacles.is_empty())
	map.free()


func test_arbol_que_cae_sobre_el_enemigo_le_pega() -> void:
	var map = _map_with_tree(Vector2(26.2, 15))
	var result: Dictionary = map.obstacles.trees.movement.fell_tree(map.obstacles.trees.queries.tree_at(Vector2(26.2, 15)), Vector2.RIGHT)
	assert_true(result["enemy_hit"])
	map.free()


func test_talar_el_arbol_con_el_jugador_arriba_lo_tira() -> void:
	var map = _map_with_tree()
	var knocked := []
	map.scene.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	map.obstacles.trees.movement.climb_tree(map.obstacles.trees.queries.tree_at(Vector2(10, 15)), Vector2(12, 12))
	map.obstacles.trees.movement.fell_tree(map.obstacles.trees.queries.tree_at(Vector2(10, 15)), Vector2.RIGHT)
	assert_eq(knocked, [false])
	assert_false(map.obstacles.trees.queries.player_is_in_tree())
	map.free()


func test_charco_de_fuego_prende_el_arbol_y_se_consume() -> void:
	var map = _map_with_tree()
	var knocked := []
	map.scene.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	var tree: Dictionary = map.obstacles.trees.queries.tree_at(Vector2(10, 15))
	map.obstacles.trees.movement.climb_tree(tree, Vector2(12, 12))
	map.placement.puddles.place_puddle(Vector2(10.5, 16), 1.0, "fire", 3, 30)
	assert_true(map.obstacles.trees.queries.is_tree_burning(tree))
	assert_eq(knocked, [true])
	map.obstacles.trees.effects.tick_trees()
	assert_false(map.obstacles.trees.queries.tree_at(Vector2(10, 15)).is_empty())
	map.obstacles.trees.effects.tick_trees()
	assert_true(map.obstacles.trees.queries.tree_at(Vector2(10, 15)).is_empty())
	map.free()


func test_otros_charcos_no_prenden_arboles() -> void:
	var map = _map_with_tree()
	map.placement.puddles.place_puddle(Vector2(10.5, 16), 1.0, "wet")
	assert_false(map.obstacles.trees.queries.is_tree_burning(map.obstacles.trees.queries.tree_at(Vector2(10, 15))))
	map.free()


func test_golpear_un_modulo_contra_el_arbol_tira_al_de_arriba() -> void:
	var map = _map_with_tree(Vector2(14, 15))
	var knocked := []
	map.scene.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	map.obstacles.trees.movement.climb_tree(map.obstacles.trees.queries.tree_at(Vector2(14, 15)), Vector2(12, 12))
	map.obstacles.modules.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.obstacles.modules.module_at(Vector2(10, 15))
	var result: Dictionary = map.obstacles.modules.slide_module(module, Vector2.RIGHT, 10.0)
	assert_false(result["tree"].is_empty())
	assert_eq(knocked, [false])
	map.free()


func test_agua_y_hielo_apagan_arboles_en_llamas() -> void:
	var map = _map_with_tree()
	var tree: Dictionary = map.obstacles.trees.queries.tree_at(Vector2(10, 15))
	map.obstacles.trees.effects.ignite_trees_in_circle(Vector2(10, 15), 1.0)
	assert_true(map.obstacles.trees.queries.is_tree_burning(tree))
	map.placement.puddles.place_puddle(Vector2(10.5, 16), 1.0, "wet")
	assert_false(map.obstacles.trees.queries.is_tree_burning(tree))
	map.obstacles.trees.effects.ignite_trees_in_circle(Vector2(10, 15), 1.0)
	assert_eq(map.obstacles.trees.effects.extinguish_trees_in_circle(Vector2(10, 15), 1.0), 1)
	map.free()


func test_el_rayo_se_frena_en_el_primer_arbol() -> void:
	var map = _map_with_tree(Vector2(8, 15))
	var rod: Dictionary = map.obstacles.trees.queries.first_tree_on_segment(Vector2(2, 15), Vector2(20, 15))
	assert_false(rod.is_empty())
	assert_lt(rod["t"], 0.5)
	assert_true(map.obstacles.trees.queries.first_tree_on_segment(Vector2(2, 10), Vector2(20, 10)).is_empty())
	map.free()


func test_charco_de_planta_junto_a_un_arbol_es_mas_grande() -> void:
	var map = _map_with_tree()
	map.placement.puddles.place_puddle(Vector2(11.5, 15), 1.0, "vine")
	map.placement.puddles.place_puddle(Vector2(25, 5), 1.0, "vine")
	assert_almost_eq(float(map.effects.puddles()[0]["radius"]), 1.0 * TreeSystem.TREE_VINE_RADIUS_MULT, 0.001)
	assert_almost_eq(float(map.effects.puddles()[1]["radius"]), 1.0, 0.001)
	map.free()


func test_el_fuego_del_arbol_se_propaga_por_la_planta_a_otro_arbol() -> void:
	var map = _map_with_tree(Vector2(10, 15))
	map.solid_obstacles.append({"pos": Vector2(13, 15), "radius": 0.6, "type": "tree"})
	map.placement.puddles.place_puddle(Vector2(11.5, 15), 1.0, "vine")  # une los dos árboles
	map.obstacles.trees.effects.ignite_trees_in_circle(Vector2(10, 15), 0.5)
	assert_eq(map.effects.puddles()[0]["effect"], "fire")
	assert_true(map.obstacles.trees.queries.is_tree_burning(map.obstacles.trees.queries.tree_at(Vector2(13, 15))))
	map.free()


func test_ariete_empuja_el_tronco_entero() -> void:
	var map = _map_with_tree(Vector2(10, 10))
	map.obstacles.trees.movement.fell_tree(map.obstacles.trees.queries.tree_at(Vector2(10, 10)), Vector2.RIGHT)
	var before: Array = map.solid_obstacles.map(func(o): return o["pos"])
	map.obstacles.modules.slide_module(map.obstacles.modules.module_at(Vector2(10, 10)), Vector2.DOWN, 3.0)
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
	map.scene.input.lock_hover_at_last_click()
	assert_true(map.scene.input.is_hover_locked())
	map.scene.input.unlock_hover()
	assert_false(map.scene.input.is_hover_locked())
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

