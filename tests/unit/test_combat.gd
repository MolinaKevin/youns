extends GutTest

# Tests de lógica pura del combate.
# HP inicial y valores de energía están pendientes de balanceo — los tests
# que dependen de valores concretos están marcados con TODO.


class MockMapArea extends Node:
	var player_pos := Vector2.ZERO
	var enemy_pos  := Vector2(10.0, 0.0)
	var los_result := true

	func movement_distance(a: Vector2, b: Vector2) -> float:
		return (a - b).length()

	func has_line_of_sight(_a: Vector2, _b: Vector2) -> bool:
		return los_result

	func check_and_trigger_traps(_pos: Vector2) -> int:
		return 0

	func start_self_highlight() -> void: pass
	func clear_self_highlight() -> void: pass
	func start_attack_selection(_range: float) -> void: pass
	func clear_attack_selection() -> void: pass
	func clear_path_preview() -> void: pass
	func clear_move_selection() -> void: pass


var _map: MockMapArea


func before_each() -> void:
	_map = MockMapArea.new()
	add_child(_map)


func after_each() -> void:
	_map.queue_free()
	_map = null


# ── CombatState — valores iniciales ──────────────────────────────────────────

func test_estado_inicial_player_energy_igual_a_max() -> void:
	var s := CombatState.new()
	assert_eq(s.player_energy, s.max_energy)


func test_estado_inicial_pilas_vacias() -> void:
	var s := CombatState.new()
	assert_true(s.hand.is_empty())
	assert_true(s.draw_pile.is_empty())
	assert_true(s.discard_pile.is_empty())


func test_estado_inicial_sin_bloqueo() -> void:
	var s := CombatState.new()
	assert_eq(s.player_block, 0)
	assert_eq(s.enemy_block, 0)


# ── Fórmula de daño vs bloqueo ────────────────────────────────────────────────

func _apply_damage(s: CombatState, amount: int) -> void:
	var dmg := maxi(amount - s.enemy_block, 0)
	s.enemy_block = maxi(s.enemy_block - amount, 0)
	s.enemy_hp -= dmg


func _apply_damage_to_player(s: CombatState, amount: int) -> void:
	var dmg := maxi(amount - s.player_block, 0)
	s.player_block = maxi(s.player_block - amount, 0)
	s.player_hp -= dmg


func test_danio_sin_bloqueo_reduce_hp_completo() -> void:
	var s := CombatState.new()
	var hp_inicial := s.enemy_hp
	_apply_damage(s, 8)
	assert_eq(s.enemy_hp, hp_inicial - 8)


func test_danio_totalmente_absorbido_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.enemy_block = 10
	var hp_inicial := s.enemy_hp
	_apply_damage(s, 6)
	assert_eq(s.enemy_hp, hp_inicial)


func test_danio_totalmente_absorbido_reduce_bloqueo() -> void:
	var s := CombatState.new()
	s.enemy_block = 10
	_apply_damage(s, 6)
	assert_eq(s.enemy_block, 4)


func test_danio_parcial_reduce_hp_y_elimina_bloqueo() -> void:
	var s := CombatState.new()
	s.enemy_block = 3
	var hp_inicial := s.enemy_hp
	_apply_damage(s, 8)
	assert_eq(s.enemy_hp, hp_inicial - 5)
	assert_eq(s.enemy_block, 0)


func test_danio_exactamente_igual_al_bloqueo_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.enemy_block = 5
	var hp_inicial := s.enemy_hp
	_apply_damage(s, 5)
	assert_eq(s.enemy_hp, hp_inicial)
	assert_eq(s.enemy_block, 0)


# ── Fórmula de daño al jugador vs bloqueo ────────────────────────────────────

func test_danio_jugador_sin_bloqueo_reduce_hp_completo() -> void:
	var s := CombatState.new()
	var hp_inicial := s.player_hp
	_apply_damage_to_player(s, 8)
	assert_eq(s.player_hp, hp_inicial - 8)


func test_danio_jugador_totalmente_absorbido_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.player_block = 10
	var hp_inicial := s.player_hp
	_apply_damage_to_player(s, 6)
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 4)


func test_danio_jugador_parcial_reduce_hp_y_elimina_bloqueo() -> void:
	var s := CombatState.new()
	s.player_block = 3
	var hp_inicial := s.player_hp
	_apply_damage_to_player(s, 8)
	assert_eq(s.player_hp, hp_inicial - 5)
	assert_eq(s.player_block, 0)


func test_danio_jugador_exactamente_igual_al_bloqueo_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.player_block = 5
	var hp_inicial := s.player_hp
	_apply_damage_to_player(s, 5)
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 0)


# ── AI — scoring ──────────────────────────────────────────────────────────────

func _make_ai(p_state: CombatState) -> CombatEnemyAI:
	var ai := CombatEnemyAI.new()
	ai.setup(p_state, _map, null, Callable(), Callable(), Callable())
	return ai


func test_ai_score_hp_normal_no_aplica_multiplicador() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35
	var action := AiAction.new()
	action.base_score = 50.0
	action.score_multiplier_low_hp = 2.0
	var score: float = _make_ai(s)._compute_score(action)
	assert_almost_eq(score, 50.0, 0.01)


func test_ai_score_hp_bajo_30_porciento_aplica_multiplicador() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35  # ≈14% → low hp
	var action := AiAction.new()
	action.base_score = 50.0
	action.score_multiplier_low_hp = 2.0
	var score: float = _make_ai(s)._compute_score(action)
	assert_almost_eq(score, 100.0, 0.01)


func test_ai_score_hp_exactamente_30_porciento_no_aplica_multiplicador() -> void:
	var s := CombatState.new()
	s.enemy_hp = 3
	s.enemy_max_hp = 10  # exactamente 30%
	var action := AiAction.new()
	action.base_score = 50.0
	action.score_multiplier_low_hp = 2.0
	var score: float = _make_ai(s)._compute_score(action)
	assert_almost_eq(score, 50.0, 0.01)


# ── AI — selección de acción ──────────────────────────────────────────────────

func _make_condition(type: String, check_range: float = 12.0) -> AiCondition:
	var c := AiCondition.new()
	c.type = type
	c.check_range = check_range
	return c


func _make_action(type: String, score: float, conditions: Array) -> AiAction:
	var a := AiAction.new()
	a.action_type = type
	a.base_score = score
	for c in conditions:
		a.conditions.append(c)
	a.damage = 8
	return a


func test_ai_elige_accion_con_mayor_score() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var weak   := _make_action("move_toward", 30.0, [_make_condition("always")])
	var strong := _make_action("melee_attack", 90.0, [_make_condition("always")])

	var strategy := AiStrategy.new()
	strategy.actions.append(weak)
	strategy.actions.append(strong)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_ai_condicion_player_adjacent_verdadera_dentro_de_rango() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.5, 0.0)

	var action := _make_action("melee_attack", 90.0, [_make_condition("player_adjacent", 2.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_ai_condicion_player_adjacent_falsa_fuera_de_rango() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(10.0, 0.0)

	var action := _make_action("melee_attack", 90.0, [_make_condition("player_adjacent", 2.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


# ── AI — pick_action ─────────────────────────────────────────────────────────

func test_ai_sin_estrategia_no_elige_accion() -> void:
	var s := CombatState.new()
	assert_null(_make_ai(s).pick_action())


func test_ai_elige_melee_attack_y_devuelve_danio_correcto() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var action := _make_action("melee_attack", 90.0, [_make_condition("always")])
	action.damage = 12
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	var picked := ai.pick_action()
	assert_eq(picked.action_type, "melee_attack")
	assert_eq(picked.damage, 12)


func test_ai_elige_block_y_devuelve_block_amount_correcto() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var action := AiAction.new()
	action.action_type = "block"
	action.base_score = 80.0
	action.conditions.append(_make_condition("always"))
	action.block_amount = 5

	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	var picked := ai.pick_action()
	assert_eq(picked.action_type, "block")
	assert_eq(picked.block_amount, 5)


func test_ai_elige_move_toward() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var strategy := AiStrategy.new()
	strategy.actions.append(_make_action("move_toward", 50.0, [_make_condition("always")]))

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "move_toward")


# ── Condiciones — distancia ───────────────────────────────────────────────────

func test_condicion_player_in_range_con_los_elige_accion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)
	_map.los_result = true

	var action := _make_action("range_attack", 80.0, [_make_condition("player_in_range", 12.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_condicion_player_in_range_sin_los_no_elige_accion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)
	_map.los_result = false

	var action := _make_action("range_attack", 80.0, [_make_condition("player_in_range", 12.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


func test_condicion_player_out_of_range_elige_accion_cuando_lejos() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(15.0, 0.0)

	var action := _make_action("move_toward", 60.0, [_make_condition("player_out_of_range", 12.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_condicion_player_out_of_range_no_elige_accion_cuando_cerca() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)

	var action := _make_action("move_toward", 60.0, [_make_condition("player_out_of_range", 12.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


func test_condicion_player_far_elige_accion_cuando_muy_lejos() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(20.0, 0.0)

	var action := _make_action("move_toward", 60.0, [_make_condition("player_far")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_condicion_player_far_no_elige_accion_cuando_cerca() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)

	var action := _make_action("move_toward", 60.0, [_make_condition("player_far")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


func test_condicion_has_los_elige_accion_con_linea_de_vision() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)
	_map.los_result = true

	var action := _make_action("range_attack", 80.0, [_make_condition("has_los")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_condicion_has_los_no_elige_accion_sin_linea_de_vision() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)
	_map.los_result = false

	var action := _make_action("range_attack", 80.0, [_make_condition("has_los")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


# ── Condiciones — HP ──────────────────────────────────────────────────────────

func test_condicion_self_hp_low_activa_con_hp_menor_30_porciento() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var normal  := _make_action("melee_attack", 50.0, [_make_condition("always")])
	var retreat := _make_action("move_away",    80.0, [_make_condition("self_hp_low")])
	var strategy := AiStrategy.new()
	strategy.actions.append(normal)
	strategy.actions.append(retreat)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "move_away")


func test_condicion_self_hp_low_inactiva_con_hp_normal() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var normal  := _make_action("melee_attack", 50.0, [_make_condition("always")])
	var retreat := _make_action("move_away",    80.0, [_make_condition("self_hp_low")])
	var strategy := AiStrategy.new()
	strategy.actions.append(normal)
	strategy.actions.append(retreat)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "melee_attack")


func test_condicion_self_hp_critical_activa_con_hp_menor_15_porciento() -> void:
	var s := CombatState.new()
	s.enemy_hp = 4
	s.enemy_max_hp = 35  # ~11.4% < 15%
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var action := _make_action("move_away", 90.0, [_make_condition("self_hp_critical")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_condicion_self_hp_critical_inactiva_con_hp_exactamente_15_porciento() -> void:
	var s := CombatState.new()
	s.enemy_hp = 3
	s.enemy_max_hp = 20  # exactamente 15%
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var action := _make_action("move_away", 90.0, [_make_condition("self_hp_critical")])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


# ── Condiciones — lógica AND ──────────────────────────────────────────────────

func test_multiples_condiciones_todas_cumplidas_elige_accion() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var action := _make_action("move_away", 80.0, [
		_make_condition("player_adjacent", 2.0),
		_make_condition("self_hp_low"),
	])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


func test_multiples_condiciones_una_falla_no_elige_accion() -> void:
	var s := CombatState.new()
	s.enemy_hp = 35
	s.enemy_max_hp = 35  # self_hp_low = false
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)  # player_adjacent = true

	var action := _make_action("move_away", 80.0, [
		_make_condition("player_adjacent", 2.0),
		_make_condition("self_hp_low"),
	])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


# ── Score — multiplicador negativo ────────────────────────────────────────────

func test_score_multiplier_menor_a_1_evita_accion_cuando_hp_bajo() -> void:
	var s := CombatState.new()
	s.enemy_hp = 5
	s.enemy_max_hp = 35
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var evitar := _make_action("melee_attack", 80.0, [_make_condition("always")])
	evitar.score_multiplier_low_hp = 0.3  # 80 * 0.3 = 24 → pierde contra 50

	var preferir := _make_action("move_away", 50.0, [_make_condition("always")])
	preferir.score_multiplier_low_hp = 1.0

	var strategy := AiStrategy.new()
	strategy.actions.append(evitar)
	strategy.actions.append(preferir)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_eq(ai.pick_action().action_type, "move_away")


# ── Condición player_out_of_range — edge case LOS ────────────────────────────

func test_condicion_player_out_of_range_verdadera_sin_los_aunque_cerca() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)  # dentro del rango 12
	_map.los_result = false               # pero sin LOS

	var action := _make_action("move_toward", 60.0, [_make_condition("player_out_of_range", 12.0)])
	var strategy := AiStrategy.new()
	strategy.actions.append(action)

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_not_null(ai.pick_action())


# ── Fases — helpers ───────────────────────────────────────────────────────────

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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	assert_null(ai.pick_action())


func test_fase_desconocida_no_elige_accion() -> void:
	var s := CombatState.new()
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(1.0, 0.0)

	var phase_a := _make_phase("a", [_make_action("melee_attack", 90.0, [_make_condition("always")])])
	var strategy := _make_phase_strategy("nonexistent", [phase_a], [])

	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_away")


func test_evaluate_transitions_con_null_strategy_no_crashea() -> void:
	var s := CombatState.new()
	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, null, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
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
	ai.setup(s, _map, strategy, Callable(), Callable(), Callable())
	ai.update_tracking()  # tenía LOS

	_map.los_result = false
	ai.update_tracking()  # perdió LOS → player_hidden = true
	ai.evaluate_transitions()
	assert_eq(ai.pick_action().action_type, "move_to_last_known")


# ── CombatPlayerActions — helpers ─────────────────────────────────────────────

func _make_card(type: String, cost: int, block: int = 0, damage: int = 0) -> CardData:
	var c := CardData.new()
	c.card_type = type
	c.cost = cost
	c.block_amount = block
	c.damage = damage
	c.name = "TestCard"
	return c


func _make_player_actions(p_state: CombatState) -> CombatPlayerActions:
	var pa := CombatPlayerActions.new()
	pa.setup(p_state, _map, Callable(), Callable(), Callable())
	return pa


# ── Block card — confirm_self_action ──────────────────────────────────────────

func test_block_card_suma_block_amount_al_player_block() -> void:
	var s := CombatState.new()
	s.player_energy = 3
	s.hand.append(_make_card("block", 2, 5))

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()

	assert_eq(s.player_block, 5)


func test_block_card_descuenta_costo_de_energia() -> void:
	var s := CombatState.new()
	s.player_energy = 3
	s.hand.append(_make_card("block", 2, 5))

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()

	assert_eq(s.player_energy, 1)


func test_block_card_mueve_carta_de_mano_a_descarte() -> void:
	var s := CombatState.new()
	s.player_energy = 3
	var card := _make_card("block", 2, 5)
	s.hand.append(card)

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()

	assert_eq(s.hand.size(), 0)
	assert_eq(s.discard_pile.size(), 1)
	assert_eq(s.discard_pile[0], card)


func test_confirm_self_action_con_indice_invalido_no_muta_estado() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.pending_self_index = -1
	pa._confirm_self_action()
	assert_eq(s.player_block, 0)


# ── play_card — energy gate ───────────────────────────────────────────────────

func test_play_card_sin_energia_no_inicia_seleccion_block() -> void:
	var s := CombatState.new()
	s.player_energy = 1
	s.hand.append(_make_card("block", 3, 5))  # cost 3 > energy 1

	var pa := _make_player_actions(s)
	pa.play_card(0)

	assert_eq(pa.pending_self_index, -1)


# ── cancel_selection ──────────────────────────────────────────────────────────

func test_cancel_selection_limpia_pending_attack_index() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.pending_attack_index = 0
	pa.cancel_selection()
	assert_eq(pa.pending_attack_index, -1)


func test_cancel_selection_limpia_pending_self_index() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa.cancel_selection()
	assert_eq(pa.pending_self_index, -1)


# ── Block stacking ────────────────────────────────────────────────────────────

func test_dos_cartas_de_bloqueo_acumulan_block_amount() -> void:
	var s := CombatState.new()
	s.player_energy = 6
	s.hand.append(_make_card("block", 2, 5))
	s.hand.append(_make_card("block", 2, 3))

	var pa := _make_player_actions(s)

	pa.pending_self_index = 0
	pa._confirm_self_action()  # hand shrinks: carta 1 descartada, carta 2 queda en índice 0

	pa.pending_self_index = 0
	pa._confirm_self_action()  # carta 2

	assert_eq(s.player_block, 8)


func test_bloqueo_acumulado_absorbe_daño_combinado() -> void:
	var s := CombatState.new()
	s.player_energy = 6
	s.hand.append(_make_card("block", 2, 4))
	s.hand.append(_make_card("block", 2, 4))

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()
	pa.pending_self_index = 0
	pa._confirm_self_action()

	var hp_inicial := s.player_hp
	_apply_damage_to_player(s, 6)  # 6 daño contra 8 de bloqueo → 0 daño
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 2)
