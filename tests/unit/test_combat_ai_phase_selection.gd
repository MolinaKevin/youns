extends "res://tests/helpers/combat_test_case.gd"

## Selección de acciones según la fase activa.

func test_fase_inicial_determina_acciones_disponibles() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_b := _make_phase("b", [_make_action("move_away", 90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("a", [phase_a, phase_b])
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "melee_attack")

func test_pick_action_no_usa_acciones_de_otras_fases() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("player_adjacent", 0.1)])])
	var phase_b := _make_phase("b", [_make_action("move_away", 90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("a", [phase_a, phase_b])
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())

func test_fase_desconocida_no_elige_accion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos = Vector2(1.0, 0.0)
	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("nonexistent", [phase_a])
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())
