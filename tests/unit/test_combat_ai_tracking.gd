extends "res://tests/helpers/combat_test_case.gd"

## Seguimiento de la última posición visible y condición player_hidden.

func test_update_tracking_con_los_guarda_posicion_del_jugador() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2(5.0, 3.0)
	_map.enemy_pos = Vector2(1.0, 0.0)
	_map.los_result = true
	var ai := _make_ai(s)
	ai.update_tracking()
	assert_eq(ai.last_known_player_pos, Vector2(5.0, 3.0))

func test_update_tracking_sin_los_no_sobreescribe_posicion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2(5.0, 3.0)
	_map.enemy_pos = Vector2(1.0, 0.0)
	_map.los_result = true
	var ai := _make_ai(s)
	ai.update_tracking()
	_map.player_pos = Vector2(20.0, 0.0)
	_map.los_result = false
	ai.update_tracking()
	assert_eq(ai.last_known_player_pos, Vector2(5.0, 3.0))

func test_condicion_player_hidden_false_cuando_hay_los() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	_map.los_result = true
	var action := _make_action("move_to_last_known", 90.0, [_make_condition("player_hidden")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()
	assert_null(ai.pick_action())

func test_condicion_player_hidden_false_si_nunca_hubo_los() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	_map.los_result = false
	var action := _make_action("move_to_last_known", 90.0, [_make_condition("player_hidden")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()
	assert_null(ai.pick_action())

func test_condicion_player_hidden_true_tras_perder_los() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	_map.los_result = true
	var action := _make_action("move_to_last_known", 90.0, [_make_condition("player_hidden")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()
	_map.los_result = false
	ai.update_tracking()
	assert_not_null(ai.pick_action())

func test_player_hidden_activa_transicion_a_fase_searching() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	_map.los_result = true
	var aware := _make_phase("aware", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var searching := _make_phase("searching", [_make_action("move_to_last_known", 90.0, [_make_condition("always")])])
	var transition := _make_transition("aware", "searching", [_make_condition("player_hidden")])
	var strategy := _make_phase_strategy("aware", [aware, searching], [transition])
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()
	_map.los_result = false
	ai.update_tracking()
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_to_last_known")
