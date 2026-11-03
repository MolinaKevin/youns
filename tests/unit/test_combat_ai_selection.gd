extends "res://tests/helpers/combat_test_case.gd"

## Selección de acciones de la IA, independiente de las condiciones específicas.

func test_ai_elige_accion_con_mayor_score() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var weak := _make_action("move_toward", 30.0, [_make_condition("always")])
	var strong := _make_action("melee_attack", 90.0, [_make_condition("always")])
	var strategy := AiStrategy.new()
	strategy.actions.append(weak)
	strategy.actions.append(strong)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "melee_attack")

func test_ai_condicion_player_adjacent_verdadera_dentro_de_rango() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.5, 0.0)
	var action := _make_action("melee_attack", 90.0, [_make_condition("player_adjacent", 2.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())

func test_ai_condicion_player_adjacent_falsa_fuera_de_rango() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(10.0, 0.0)
	var action := _make_action("melee_attack", 90.0, [_make_condition("player_adjacent", 2.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())

func test_ai_sin_estrategia_no_elige_accion() -> void:
	var s := CombatState.new()
	assert_null(_make_ai(s).pick_action())

func test_ai_elige_melee_attack_y_devuelve_danio_correcto() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var action := _make_action("melee_attack", 90.0, [_make_condition("always")])
	action.damage = 12
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	var picked := ai.pick_action()
	assert_eq(picked.action_type, "melee_attack")
	assert_eq(picked.damage, 12)

func test_ai_elige_block_y_devuelve_block_amount_correcto() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var action := _make_action("block", 80.0, [_make_condition("always")], 1.0, 5)
	var strategy := AiStrategy.new()
	strategy.actions.append(action)
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	var picked := ai.pick_action()
	assert_eq(picked.action_type, "block")
	assert_eq(picked.block_amount, 5)

func test_ai_elige_move_toward() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var strategy := AiStrategy.new()
	strategy.actions.append(_make_action("move_toward", 50.0, [_make_condition("always")]))
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "move_toward")
