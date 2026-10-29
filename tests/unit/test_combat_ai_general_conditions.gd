extends "res://tests/helpers/combat_test_case.gd"

## Casos generales de condiciones combinadas y bordes de la IA.

func test_multiples_condiciones_todas_cumplidas_elige_accion() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var action := _make_action("move_away", 80.0, [
		_make_condition("player_adjacent", 2.0),
		_make_condition("self_hp_low"),
	])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())

func test_multiples_condiciones_una_falla_no_elige_accion() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var action := _make_action("move_away", 80.0, [
		_make_condition("player_adjacent", 2.0),
		_make_condition("self_hp_low"),
	])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())

func test_score_multiplier_menor_a_1_evita_accion_cuando_hp_bajo() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var evitar := _make_action("melee_attack", 80.0, [_make_condition("always")])
	evitar.score_multiplier_low_hp = 0.3
	var preferir := _make_action("move_away", 50.0, [_make_condition("always")])
	preferir.score_multiplier_low_hp = 1.0
	var strategy := AiStrategy.new()
	strategy.actions.append(evitar)
	strategy.actions.append(preferir)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "move_away")

func test_condicion_player_out_of_range_verdadera_sin_los_aunque_cerca() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(5.0, 0.0)
	_map.los_result = false
	var action := _make_action("move_toward", 60.0, [_make_condition("player_out_of_range", 12.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())
