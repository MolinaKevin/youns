extends "res://tests/helpers/combat_test_case.gd"

## Fases, transiciones y seguimiento de visibilidad de la IA.

# ── Fases — transiciones ──────────────────────────────────────────────────────

func test_transicion_ocurre_cuando_condicion_cumplida() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35  # self_hp_low = true
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var phase_normal := _make_phase("normal", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_flee   := _make_phase("flee",   [_make_action("move_away",    90.0, [_make_condition("always")])])
	var trans := _make_transition("normal", "flee", [_make_condition("self_hp_low")])
	var strategy := _make_phase_strategy("normal", [phase_normal, phase_flee], [trans])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_away")


func test_no_transicion_cuando_condicion_no_cumplida() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35  # self_hp_low = false
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var phase_normal := _make_phase("normal", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_flee   := _make_phase("flee",   [_make_action("move_away",    90.0, [_make_condition("always")])])
	var trans := _make_transition("normal", "flee", [_make_condition("self_hp_low")])
	var strategy := _make_phase_strategy("normal", [phase_normal, phase_flee], [trans])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_primera_transicion_valida_gana() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35  # self_hp_low = true
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)  # player_adjacent = true (range 2)

	var phase_normal  := _make_phase("normal",  [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_flee    := _make_phase("flee",     [_make_action("move_away",   90.0, [_make_condition("always")])])
	var phase_berserk := _make_phase("berserk",  [_make_action("range_attack",90.0, [_make_condition("always")])])

	# Ambas condiciones se cumplen; la primera en la lista gana
	var trans_flee    := _make_transition("normal", "flee",    [_make_condition("self_hp_low")])
	var trans_berserk := _make_transition("normal", "berserk", [_make_condition("player_adjacent", 2.0)])
	var strategy := _make_phase_strategy("normal",
		[phase_normal, phase_flee, phase_berserk],
		[trans_flee, trans_berserk])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_away")


func test_transicion_de_fase_no_activa_no_se_aplica() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35  # self_hp_low = true
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var phase_normal := _make_phase("normal", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_flee   := _make_phase("flee",   [_make_action("move_away",    90.0, [_make_condition("always")])])
	var phase_other  := _make_phase("other",  [_make_action("range_attack", 90.0, [_make_condition("always")])])

	# Transición desde "other" (no es la fase actual) no debe activarse
	var trans := _make_transition("other", "flee", [_make_condition("self_hp_low")])
	var strategy := _make_phase_strategy("normal", [phase_normal, phase_flee, phase_other], [trans])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_transicion_con_condicion_de_rango() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)  # distancia 1 <= rango 2 → player_adjacent true

	var phase_normal  := _make_phase("normal",  [_make_action("move_toward",  90.0, [_make_condition("always")])])
	var phase_melee   := _make_phase("melee",   [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var trans := _make_transition("normal", "melee", [_make_condition("player_adjacent", 2.0)])
	var strategy := _make_phase_strategy("normal", [phase_normal, phase_melee], [trans])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_transicion_multiples_condiciones_and_una_falla_no_transiciona() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35   # self_hp_low = true
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(10.0, 0.0)  # player_adjacent (rango 2) = false

	var phase_normal := _make_phase("normal", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_flee   := _make_phase("flee",   [_make_action("move_away",    90.0, [_make_condition("always")])])
	var trans := _make_transition("normal", "flee", [
		_make_condition("self_hp_low"),
		_make_condition("player_adjacent", 2.0),
	])
	var strategy := _make_phase_strategy("normal", [phase_normal, phase_flee], [trans])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_evaluate_transitions_no_encadena_en_misma_llamada() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	# A → B (always), B → C (always)
	# Después de una llamada debe quedar en B, no en C
	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_b := _make_phase("b", [_make_action("move_away",    90.0, [_make_condition("always")])])
	var phase_c := _make_phase("c", [_make_action("range_attack", 90.0, [_make_condition("always")])])
	var trans_ab := _make_transition("a", "b", [_make_condition("always")])
	var trans_bc := _make_transition("b", "c", [_make_condition("always")])
	var strategy := _make_phase_strategy("a", [phase_a, phase_b, phase_c], [trans_ab, trans_bc])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_away")


func test_evaluate_transitions_con_null_strategy_no_crashea() -> void:
	var s := CombatState.new()
	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, null, Callable(), Callable(), Callable())
	ai.evaluate_transitions()  # no debe crashear
	assert_null(ai.pick_action())
