extends "res://tests/helpers/combat_test_case.gd"

## Fases, transiciones y seguimiento de visibilidad de la IA.

func _make_phase(phase_name: String, actions: Array) -> AiPhase:
	var p := AiPhase.new()
	p.phase_name = phase_name
	for a in actions:
		p.actions.append(a)
	return p


func _make_transition(from: String, to: String, conditions: Array) -> AiPhaseTransition:
	var t := AiPhaseTransition.new()
	t.from_phase = from
	t.target_phase = to
	for c in conditions:
		t.conditions.append(c)
	return t


func _make_phase_strategy(initial: String, phases: Array, transitions: Array) -> AiStrategy:
	var s := AiStrategy.new()
	s.initial_phase = initial
	for p in phases:
		s.phases.append(p)
	for t in transitions:
		s.transitions.append(t)
	return s


# ── Fases — selección de acción por fase ─────────────────────────────────────

func test_fase_inicial_determina_acciones_disponibles() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var phase_b := _make_phase("b", [_make_action("move_away",    90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("a", [phase_a, phase_b], [])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_pick_action_no_usa_acciones_de_otras_fases() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	# Fase activa "a" no tiene acciones elegibles; fase "b" sí, pero no debe usarse
	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("player_adjacent", 0.1)])])
	var phase_b := _make_phase("b", [_make_action("move_away",    90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("a", [phase_a, phase_b], [])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


func test_fase_desconocida_no_elige_accion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("nonexistent", [phase_a], [])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


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


# ── Última posición conocida ──────────────────────────────────────────────────

func test_update_tracking_con_los_guarda_posicion_del_jugador() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2(5.0, 3.0)
	_map.enemy_pos  = Vector2(1.0, 0.0)
	_map.los_result = true

	var ai := _make_ai(s)
	ai.update_tracking()
	assert_eq(ai.last_known_player_pos, Vector2(5.0, 3.0))


func test_update_tracking_sin_los_no_sobreescribe_posicion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2(5.0, 3.0)
	_map.enemy_pos  = Vector2(1.0, 0.0)
	_map.los_result = true

	var ai := _make_ai(s)
	ai.update_tracking()  # guarda (5, 3)

	_map.player_pos = Vector2(20.0, 0.0)
	_map.los_result = false
	ai.update_tracking()  # no debe actualizar

	assert_eq(ai.last_known_player_pos, Vector2(5.0, 3.0))


func test_condicion_player_hidden_false_cuando_hay_los() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)
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
	_map.enemy_pos  = Vector2(1.0, 0.0)
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
	_map.enemy_pos  = Vector2(1.0, 0.0)
	_map.los_result = true

	var action := _make_action("move_to_last_known", 90.0, [_make_condition("player_hidden")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()   # tenía LOS

	_map.los_result = false
	ai.update_tracking()   # perdió LOS → player_hidden = true
	assert_not_null(ai.pick_action())


func test_player_hidden_activa_transicion_a_fase_searching() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)
	_map.los_result = true

	var phase_aware     := _make_phase("aware",     [_make_action("melee_attack",       90.0, [_make_condition("always")])])
	var phase_searching := _make_phase("searching", [_make_action("move_to_last_known", 90.0, [_make_condition("always")])])
	var trans := _make_transition("aware", "searching", [_make_condition("player_hidden")])
	var strategy := _make_phase_strategy("aware", [phase_aware, phase_searching], [trans])

	var ai := CombatEnemyAI.new()
	ai.setup_with_board(s, _enemy_board, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()  # tenía LOS

	_map.los_result = false
	ai.update_tracking()  # perdió LOS → player_hidden = true
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_to_last_known")

