extends "res://tests/helpers/combat_test_case.gd"

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")
const BoardFixture := preload("res://tests/helpers/combat_board_fixture.gd")

func _map_for_modules():
	return BoardFixture.empty_modules_map()

func test_hay_arboles_para_trepar() -> void:
	var map = MapAreaScript.new()
	assert_eq(map.obstacles.trees.queries.tree_at(Vector2(5.0, 24.0)).get("type"), "tree")
	assert_true(map.obstacles.trees.queries.tree_at(Vector2(15.0, 15.0)).is_empty())  # piedra, no árbol
	assert_true(map.terrain.geometry.collision.is_blocked(Vector2(5.0, 24.0)))
	map.free()


func test_caer_del_arbol_sobre_el_enemigo_queda_pegado_a_el() -> void:
	var map = MapAreaScript.new()
	map.player_pos = Vector2(5.0, 25.4)
	map.enemy_pos = Vector2(8.0, 24.0)
	var tree: Dictionary = map.obstacles.trees.queries.tree_at(Vector2(5.0, 24.0))
	map.obstacles.trees.movement.climb_tree(tree, map.enemy_pos)
	assert_true(map.obstacles.trees.queries.player_is_in_tree())
	assert_true(map.obstacles.trees.movement.drop_from_tree(map.enemy_pos))
	assert_false(map.obstacles.trees.queries.player_is_in_tree())
	assert_almost_eq(map.player_pos.distance_to(map.enemy_pos), map.MIN_SEPARATION, 0.01)
	map.free()


func test_caer_del_arbol_en_un_lugar_libre() -> void:
	var map = MapAreaScript.new()
	map.player_pos = Vector2(5.0, 25.4)
	var tree: Dictionary = map.obstacles.trees.queries.tree_at(Vector2(5.0, 24.0))
	map.obstacles.trees.movement.climb_tree(tree, Vector2(8.0, 26.0))
	assert_false(map.obstacles.trees.movement.drop_from_tree(Vector2(8.0, 26.0)))
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


