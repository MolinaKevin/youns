extends "res://tests/helpers/combat_test_case.gd"

## Condiciones de distancia y línea de visión de la IA.

func _assert_condition(action_type: String, condition_type: String, value: float, enemy_position: Vector2, los: bool, expected: bool) -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = enemy_position
	_map.los_result = los
	var action := _make_action(action_type, 80.0, [_make_condition(condition_type, value)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	if expected:
		assert_not_null(ai.pick_action())
	else:
		assert_null(ai.pick_action())

func test_condicion_player_in_range_con_los_elige_accion() -> void:
	_assert_condition("range_attack", "player_in_range", 12.0, Vector2(5.0, 0.0), true, true)

func test_condicion_player_in_range_sin_los_no_elige_accion() -> void:
	_assert_condition("range_attack", "player_in_range", 12.0, Vector2(5.0, 0.0), false, false)

func test_condicion_player_out_of_range_elige_accion_cuando_lejos() -> void:
	_assert_condition("move_toward", "player_out_of_range", 12.0, Vector2(15.0, 0.0), true, true)

func test_condicion_player_out_of_range_no_elige_accion_cuando_cerca() -> void:
	_assert_condition("move_toward", "player_out_of_range", 12.0, Vector2(5.0, 0.0), true, false)

func test_condicion_player_far_elige_accion_cuando_muy_lejos() -> void:
	_assert_condition("move_toward", "player_far", 0.0, Vector2(20.0, 0.0), true, true)

func test_condicion_player_far_no_elige_accion_cuando_cerca() -> void:
	_assert_condition("move_toward", "player_far", 0.0, Vector2(5.0, 0.0), true, false)

func test_condicion_has_los_elige_accion_con_linea_de_vision() -> void:
	_assert_condition("range_attack", "has_los", 0.0, Vector2(5.0, 0.0), true, true)

func test_condicion_has_los_no_elige_accion_sin_linea_de_vision() -> void:
	_assert_condition("range_attack", "has_los", 0.0, Vector2(5.0, 0.0), false, false)
