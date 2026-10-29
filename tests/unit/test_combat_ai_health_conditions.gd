extends "res://tests/helpers/combat_test_case.gd"

## Condiciones de vida propia de la IA.

func test_condicion_self_hp_low_activa_con_hp_menor_30_porciento() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var normal := _make_action("melee_attack", 50.0, [_make_condition("always")])
	var retreat := _make_action("move_away", 80.0, [_make_condition("self_hp_low")])
	var strategy := AiStrategy.new()
	strategy.actions.append(normal)
	strategy.actions.append(retreat)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "move_away")

func test_condicion_self_hp_low_inactiva_con_hp_normal() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var normal := _make_action("melee_attack", 50.0, [_make_condition("always")])
	var retreat := _make_action("move_away", 80.0, [_make_condition("self_hp_low")])
	var strategy := AiStrategy.new()
	strategy.actions.append(normal)
	strategy.actions.append(retreat)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "melee_attack")

func test_condicion_self_hp_critical_activa_con_hp_menor_15_porciento() -> void:
	var s := CombatState.new()
	s.enemy_hp = 4
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var action := _make_action("move_away", 90.0, [_make_condition("self_hp_critical")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())

func test_condicion_self_hp_critical_inactiva_con_hp_exactamente_15_porciento() -> void:
	var s := CombatState.new()
	s.enemy_hp = 3
	s.enemy_max_hp = 20
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var action := _make_action("move_away", 90.0, [_make_condition("self_hp_critical")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())
