extends GutTest

# Tests de lógica pura del combate.
# HP inicial y valores de energía están pendientes de balanceo — los tests
# que dependen de valores concretos están marcados con TODO.


class MockMapArea extends Node:
	const WORLD_W := 30.0
	const WORLD_H := 30.0

	var player_pos := Vector2.ZERO
	var enemy_pos  := Vector2(10.0, 0.0)
	var los_result := true
	var puddle_effects_result: Dictionary = {}
	var puddle_damage_result: Dictionary = {}
	var overwatch_cone_hit := false

	var move_enemy_toward_calls := 0
	var start_move_selection_calls := 0
	var clear_overwatch_zone_calls := 0
	var place_puddle_calls: Array = []

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

	func move_enemy_toward(_target: Vector2, _move_range: float) -> bool:
		move_enemy_toward_calls += 1
		return true

	func get_puddle_effects_along(_from: Vector2, _to: Vector2) -> Dictionary:
		return puddle_effects_result

	func get_puddle_damage_along(_from: Vector2, _to: Vector2) -> Dictionary:
		return puddle_damage_result

	func start_move_selection(_range: float) -> void:
		start_move_selection_calls += 1

	func start_puddle_placement(_throw_range: float, _effect: String = "wet", _radius: float = 1.0) -> void: pass
	func clear_puddle_placement() -> void: pass

	func place_puddle(pos: Vector2, radius: float, effect: String = "wet", turns: int = 0, damage: int = 0) -> void:
		place_puddle_calls.append({"pos": pos, "radius": radius, "effect": effect, "turns": turns, "damage": damage})

	func start_overwatch_selection(_cone_range: float, _half_angle: float) -> void: pass
	func clear_overwatch_selection() -> void: pass
	func place_overwatch(_origin: Vector2, _dir: Vector2, _cone_range: float, _half_angle: float) -> void: pass

	func clear_overwatch_zone() -> void:
		clear_overwatch_zone_calls += 1

	func is_enemy_in_attack_range(_range: float) -> bool:
		return true

	func actors_gap() -> float:
		return (player_pos - enemy_pos).length() - 1.3  # huellas de ejemplo (radio 0,65 cada una)

	func is_segment_in_overwatch_cone(_from: Vector2, _to: Vector2, _origin: Vector2, _dir: Vector2, _cone_range: float, _half_angle_deg: float) -> bool:
		return overwatch_cone_hit


var _map: MockMapArea


func before_each() -> void:
	_map = MockMapArea.new()
	add_child(_map)


func after_each() -> void:
	_map.queue_free()
	_map = null


# ── CombatState — valores iniciales ──────────────────────────────────────────

func test_estado_inicial_pilas_vacias() -> void:
	var s := CombatState.new()
	assert_true(s.hand.is_empty())
	assert_true(s.draw_pile.is_empty())
	assert_true(s.discard_pile.is_empty())


func test_resumen_de_estados_para_mostrar_sobre_los_personajes() -> void:
	var s := CombatState.new()
	assert_eq(s.status_summary(true), "")
	s.player_burning_turns = 2
	s.player_block = 30
	s.player_in_tree = true
	assert_eq(s.status_summary(true), "Fuego 2 · Bloqueo 30 · En el árbol")
	s.enemy_wet_turns = 3
	s.enemy_ward = 20
	assert_eq(s.status_summary(false), "Mojado 3 · Escudo mágico 20")


func test_estado_inicial_sin_bloqueo() -> void:
	var s := CombatState.new()
	assert_eq(s.player_block, 0)
	assert_eq(s.enemy_block, 0)


# ── Fórmula de daño vs bloqueo ────────────────────────────────────────────────

func _apply_damage(s: CombatState, amount: int) -> void:
	s.damage_enemy(amount)


func _apply_damage_to_player(s: CombatState, amount: int) -> void:
	s.damage_player(amount)


# ── MP ────────────────────────────────────────────────────────────────────────

func test_restore_mp_suma_sin_pasar_el_maximo() -> void:
	var s := CombatState.new()
	s.player_max_mp = 100
	s.player_mp = 50
	assert_eq(s.restore_mp(30), 30)
	assert_eq(s.player_mp, 80)
	assert_eq(s.restore_mp(30), 20)
	assert_eq(s.player_mp, 100)


func test_mp_cost_de_una_mitad_suma_solo_lineas_activas() -> void:
	var half := CardAction.new()
	for cost in [20, 15, 30]:
		var line := CardActionLine.new()
		line.mp_cost = cost
		half.lines.append(line)
	half.lines[2].enabled = false
	assert_eq(half.mp_cost(), 35)


func test_meteor_y_barrera_cuestan_mp() -> void:
	assert_gt(CardDatabase.cards_by_id["meteor"].top.mp_cost(), 0)
	assert_gt(CardDatabase.cards_by_id["barrera"].top.mp_cost(), 0)


func test_meditar_recupera_mp_escalando_con_espiritu() -> void:
	var line: CardActionLine = CardDatabase.cards_by_id["meditar"].top.lines[0]
	assert_eq(line.card_type, "mp_restore")
	var low := line.resolved({"espiritu": 20}).restore_amount
	var high := line.resolved({"espiritu": 100}).restore_amount
	assert_gt(high, low)


# ── Tipo de daño: físico → bloqueo, mágico → escudo mágico ───────────────────

func test_danio_magico_lo_absorbe_el_escudo_magico_no_el_bloqueo() -> void:
	var s := CombatState.new()
	s.enemy_block = 50
	s.enemy_ward = 30
	var hp_inicial := s.enemy_hp
	assert_eq(s.damage_enemy(40, CombatState.MAGICO), 10)
	assert_eq(s.enemy_hp, hp_inicial - 10)
	assert_eq(s.enemy_ward, 0)
	assert_eq(s.enemy_block, 50)


func test_danio_fisico_no_usa_el_escudo_magico() -> void:
	var s := CombatState.new()
	s.player_ward = 100
	var hp_inicial := s.player_hp
	assert_eq(s.damage_player(40), 40)
	assert_eq(s.player_hp, hp_inicial - 40)
	assert_eq(s.player_ward, 100)


func test_danio_magico_al_jugador_gasta_escudo_magico() -> void:
	var s := CombatState.new()
	s.player_block = 100
	s.player_ward = 25
	var hp_inicial := s.player_hp
	s.damage_player(20, CombatState.MAGICO)
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_ward, 5)
	assert_eq(s.player_block, 100)


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

func _make_card(type: String, block: int = 0, damage: int = 0) -> CardActionLine:
	var c := CardActionLine.new()
	c.card_type = type
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
	s.turn_actions.append(_make_card("block", 5))

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()

	assert_eq(s.player_block, 5)


func test_block_card_consume_la_accion_del_turno() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("block", 5))

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()

	assert_eq(s.turn_actions.size(), 0)


func test_confirm_self_action_con_indice_invalido_no_muta_estado() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.pending_self_index = -1
	pa._confirm_self_action()
	assert_eq(s.player_block, 0)


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
	s.turn_actions.append(_make_card("block", 5))
	s.turn_actions.append(_make_card("block", 3))

	var pa := _make_player_actions(s)

	pa.pending_self_index = 0
	pa._confirm_self_action()  # acción 1 consumida, acción 2 queda en índice 0

	pa.pending_self_index = 0
	pa._confirm_self_action()  # carta 2

	assert_eq(s.player_block, 8)


func test_bloqueo_acumulado_absorbe_daño_combinado() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("block", 4))
	s.turn_actions.append(_make_card("block", 4))

	var pa := _make_player_actions(s)
	pa.pending_self_index = 0
	pa._confirm_self_action()
	pa.pending_self_index = 0
	pa._confirm_self_action()

	var hp_inicial := s.player_hp
	_apply_damage_to_player(s, 6)  # 6 daño contra 8 de bloqueo → 0 daño
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 2)


# ── Estados de combate — helpers ─────────────────────────────────────────────

func _dmg_enemy_callable(s: CombatState) -> Callable:
	return func(amount: int, _skip_anim: bool = false, damage_type: String = CombatState.FISICO) -> void:
		s.damage_enemy(amount, damage_type)


func _dmg_player_callable(s: CombatState) -> Callable:
	return func(amount: int, _skip_anim: bool = false, damage_type: String = CombatState.FISICO) -> void:
		s.damage_player(amount, damage_type)


func _check_end_callable(s: CombatState) -> Callable:
	return func() -> bool:
		return s.enemy_hp <= 0 or s.player_hp <= 0


func _make_ai_full(s: CombatState, strategy: AiStrategy = null) -> CombatEnemyAI:
	var ai := CombatEnemyAI.new()
	ai.setup(s, _map, strategy, _dmg_enemy_callable(s), _dmg_player_callable(s), _check_end_callable(s))
	return ai


# ── Estados — quemado / sangrado / veneno (DOT del enemigo) ─────────────────

func test_enemy_quemado_aplica_su_danio_y_decrementa_turnos() -> void:
	var s := CombatState.new()
	s.enemy_hp = 200
	s.enemy_burning_turns = 2
	await _make_ai_full(s).take_turn()
	assert_eq(s.enemy_hp, 200 - CombatState.BURN_DAMAGE)
	assert_eq(s.enemy_burning_turns, 1)


func test_enemy_quemado_se_apaga_al_llegar_a_cero() -> void:
	var s := CombatState.new()
	s.enemy_hp = 200
	s.enemy_burning_turns = 1
	await _make_ai_full(s).take_turn()
	assert_eq(s.enemy_burning_turns, 0)


func test_enemy_sangrado_aplica_su_danio_y_decrementa_turnos() -> void:
	var s := CombatState.new()
	s.enemy_hp = 200
	s.enemy_bleeding_turns = 2
	await _make_ai_full(s).take_turn()
	assert_eq(s.enemy_hp, 200 - CombatState.BLEED_DAMAGE)
	assert_eq(s.enemy_bleeding_turns, 1)


func test_enemy_veneno_aplica_danio_por_stack_y_los_decrementa() -> void:
	var s := CombatState.new()
	s.enemy_hp = 200
	s.enemy_poison_stacks = 3
	await _make_ai_full(s).take_turn()
	assert_eq(s.enemy_hp, 200 - 3 * CombatState.POISON_DAMAGE_PER_STACK)
	assert_eq(s.enemy_poison_stacks, 2)


func test_enemy_dots_acumulados_se_aplican_todos_en_el_mismo_turno() -> void:
	var s := CombatState.new()
	s.enemy_hp = 300
	s.enemy_burning_turns  = 1
	s.enemy_bleeding_turns = 1
	s.enemy_poison_stacks  = 2
	await _make_ai_full(s).take_turn()
	assert_eq(s.enemy_hp, 300 - CombatState.BURN_DAMAGE - CombatState.BLEED_DAMAGE - 2 * CombatState.POISON_DAMAGE_PER_STACK)


func test_enemy_muerte_por_dot_detiene_los_ticks_siguientes() -> void:
	var s := CombatState.new()
	s.enemy_hp = 1
	s.enemy_burning_turns  = 1
	s.enemy_bleeding_turns = 1
	await _make_ai_full(s).take_turn()
	assert_true(s.enemy_hp <= 0)
	assert_eq(s.enemy_burning_turns, 1)   # murió antes de decrementarse
	assert_eq(s.enemy_bleeding_turns, 1)  # el tick de sangrado nunca corrió


# ── Estados — penalización de movimiento (mojado / engrasado) ───────────────

func test_enemy_move_penalty_suma_mojado_y_engrasado() -> void:
	var s := CombatState.new()
	s.enemy_wet_turns = 1
	s.enemy_greasy_turns = 1
	assert_eq(_make_ai_full(s)._enemy_move_penalty(), 3)


func test_enemy_move_penalty_cero_sin_estados() -> void:
	var s := CombatState.new()
	assert_eq(_make_ai_full(s)._enemy_move_penalty(), 0)


# ── Estados — inmovilización (enredado / congelado) del enemigo ─────────────

func test_enemy_enredado_no_puede_moverse() -> void:
	var s := CombatState.new()
	s.enemy_entangled_turns = 2
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s)._execute_action(action)
	assert_eq(_map.move_enemy_toward_calls, 0)


func test_enemy_congelado_no_puede_moverse() -> void:
	var s := CombatState.new()
	s.enemy_frozen_turns = 2
	var action := _make_action("move_away", 50.0, [_make_condition("always")])
	await _make_ai_full(s)._execute_action(action)
	assert_eq(_map.move_enemy_toward_calls, 0)


func test_enemy_sin_inmovilizacion_puede_moverse() -> void:
	var s := CombatState.new()
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s)._execute_action(action)
	assert_eq(_map.move_enemy_toward_calls, 1)


# ── Estados — ceguera ─────────────────────────────────────────────────────────

func test_enemy_cegado_bloquea_ataque_a_distancia_mayor_a_2() -> void:
	var s := CombatState.new()
	s.enemy_blinded_turns = 1
	s.player_hp = 20
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(5.0, 0.0)
	var action := _make_action("range_attack", 50.0, [_make_condition("always")])
	action.damage = 10
	await _make_ai_full(s)._execute_action(action)
	assert_eq(s.player_hp, 20)


func test_enemy_cegado_permite_ataque_a_distancia_menor_igual_a_2() -> void:
	var s := CombatState.new()
	s.enemy_blinded_turns = 1
	s.player_hp = 20
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(2.0, 0.0)
	var action := _make_action("range_attack", 50.0, [_make_condition("always")])
	action.damage = 10
	await _make_ai_full(s)._execute_action(action)
	assert_eq(s.player_hp, 10)


# ── Overwatch — emboscada al enemigo ─────────────────────────────────────────

func test_overwatch_activo_dispara_al_enemigo_si_entra_en_el_cono() -> void:
	var s := CombatState.new()
	s.enemy_hp = 20
	s.player_overwatch_active = true
	s.player_overwatch_damage = 7
	_map.overwatch_cone_hit = true
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s)._execute_action(action)
	assert_eq(s.enemy_hp, 13)
	assert_false(s.player_overwatch_active)
	assert_eq(_map.clear_overwatch_zone_calls, 1)


func test_overwatch_no_se_dispara_si_el_enemigo_no_entra_en_el_cono() -> void:
	var s := CombatState.new()
	s.enemy_hp = 20
	s.player_overwatch_active = true
	s.player_overwatch_damage = 7
	_map.overwatch_cone_hit = false
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s)._execute_action(action)
	assert_eq(s.enemy_hp, 20)
	assert_true(s.player_overwatch_active)


# ── CombatPlayerActions — estados bloquean/penalizan movimiento ─────────────

func test_start_move_selection_bloqueada_por_enredado() -> void:
	var s := CombatState.new()
	s.player_entangled_turns = 2
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 3, "Test")
	assert_eq(pa.pending_move_index, -1)
	assert_eq(_map.start_move_selection_calls, 0)


func test_start_move_selection_bloqueada_por_congelado() -> void:
	var s := CombatState.new()
	s.player_frozen_turns = 2
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 3, "Test")
	assert_eq(pa.pending_move_index, -1)
	assert_eq(_map.start_move_selection_calls, 0)


func test_start_move_selection_penaliza_rango_por_mojado_y_engrasado() -> void:
	var s := CombatState.new()
	s.player_wet_turns = 1
	s.player_greasy_turns = 1
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 50, "Test")
	assert_eq(pa.pending_move_range, 12)  # 50 - (13 mojado + 25 engrasado), en casillas


# ── CombatPlayerActions — ceguera reduce rango de ataque ─────────────────────

func test_start_range_attack_selection_reduce_rango_por_cegado() -> void:
	var s := CombatState.new()
	s.player_blinded_turns = 1
	var card := _make_card("range_attack", 0, 8)
	card.card_range = 50
	var pa := _make_player_actions(s)
	pa.start_range_attack_selection(0, card)
	assert_eq(pa.pending_attack_range, CombatPlayerActions.BLINDED_RANGE)


func test_start_range_attack_selection_sin_cegado_usa_rango_completo() -> void:
	var s := CombatState.new()
	var card := _make_card("range_attack", 0, 8)
	card.card_range = 5
	var pa := _make_player_actions(s)
	pa.start_range_attack_selection(0, card)
	assert_eq(pa.pending_attack_range, 5)


# ── CombatPlayerActions — charcos usan el effect/rango de la carta ──────────

func test_execute_puddle_usa_el_effect_y_rango_de_la_carta() -> void:
	var s := CombatState.new()
	var card := _make_card("puddle")
	card.puddle_effect = "fire"
	card.card_range = 2
	s.turn_actions.append(card)
	var pa := _make_player_actions(s)
	pa.pending_puddle_index = 0
	pa._execute_puddle(Vector2(4.0, 2.0))
	assert_eq(_map.place_puddle_calls.size(), 1)
	assert_eq(_map.place_puddle_calls[0]["effect"], "fire")
	assert_almost_eq(_map.place_puddle_calls[0]["radius"], 2 * CombatGrid.CELL, 0.0001)  # 2 casillas
	assert_eq(_map.place_puddle_calls[0]["pos"], Vector2(4.0, 2.0))


func test_execute_puddle_pasa_duracion_y_danio() -> void:
	var s := CombatState.new()
	var card := _make_card("puddle")
	card.puddle_effect = "fire"
	card.card_range = 2
	card.duration = 4
	card.damage = 45
	s.turn_actions.append(card)
	var pa := _make_player_actions(s)
	pa.pending_puddle_index = 0
	pa._execute_puddle(Vector2(4.0, 2.0))
	assert_eq(_map.place_puddle_calls[0]["turns"], 4)
	assert_eq(_map.place_puddle_calls[0]["damage"], 45)


func test_enemigo_que_pisa_fuego_toma_el_danio_del_charco() -> void:
	var s := CombatState.new()
	var ai := _make_ai(s)
	_map.puddle_effects_result = {"fire": true, "poison": true}
	_map.puddle_damage_result = {"fire": 55, "poison": 14}
	ai._apply_enemy_zone_effects(Vector2.ZERO)
	assert_eq(s.enemy_burning_turns, 3)
	assert_eq(s.enemy_burn_damage, 55)
	assert_eq(s.enemy_poison_damage, 14)


func test_charco_sin_danio_propio_usa_el_danio_por_defecto() -> void:
	var s := CombatState.new()
	var ai := _make_ai(s)
	_map.puddle_effects_result = {"fire": true}
	ai._apply_enemy_zone_effects(Vector2.ZERO)
	assert_eq(s.enemy_burn_damage, CombatState.BURN_DAMAGE)


# ── Charcos en el mapa: duración ─────────────────────────────────────────────

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")


func test_charco_con_duracion_desaparece_al_pasar_sus_rondas() -> void:
	var map = MapAreaScript.new()
	map.place_puddle(Vector2(5, 5), 1.0, "fire", 2, 40)
	map.place_puddle(Vector2(15, 15), 1.0, "wet")  # sin duración
	map.tick_puddles()
	assert_eq(map.puddle_zones.size(), 2)
	map.tick_puddles()
	assert_eq(map.puddle_zones.size(), 1)
	assert_eq(map.puddle_zones[0]["effect"], "wet")
	assert_eq(map._puddle_visuals.size(), 1)
	map.free()


func test_lente_dura_lo_que_el_charco_mas_corto() -> void:
	var map = MapAreaScript.new()
	map.place_puddle(Vector2(5, 5), 1.0, "blood", 3, 20)
	map.place_puddle(Vector2(6, 5), 1.0, "ice", 1)
	var lens: Dictionary = map.puddle_zones.filter(func(z): return z["lens"])[0]
	assert_eq(lens["effect"], "bloody_ice")
	assert_eq(lens["turns"], 1)
	assert_eq(lens["damage"], 20)
	map.tick_puddles()
	assert_eq(map.puddle_zones.size(), 1)
	assert_eq(map.puddle_zones[0]["effect"], "blood")
	assert_true(map.puddle_zones[0]["excl"].is_empty())
	map.free()


func test_arrastre_acerca_al_enemigo_sin_pasarse() -> void:
	var map = MapAreaScript.new()
	map.enemy_pos = Vector2(2, 2)
	assert_eq(map.calculate_drag_landing(Vector2(2, 10), 3.0), Vector2(2, 5))
	assert_eq(map.calculate_drag_landing(Vector2(2, 10), 20.0), Vector2(2, 10))
	map.free()


func test_arrastre_se_frena_en_un_obstaculo() -> void:
	var map = MapAreaScript.new()
	map.enemy_pos = Vector2(14, 25)  # al sur del obstáculo sólido de (14, 19), radio 1,5
	var landing: Vector2 = map.calculate_drag_landing(Vector2(14, 12), 20.0)
	assert_gt(landing.y, 20.5)
	map.free()


func test_romper_modulo_libera_el_paso() -> void:
	var map = MapAreaScript.new()
	var rock: Dictionary = map.get_module_at(Vector2(15.0, 15.0))
	assert_eq(rock.get("type"), "rock")
	assert_true(map._pos_blocked(Vector2(15.0, 15.0)))
	assert_eq(map.break_modules(rock, 1), 1)
	assert_false(map._pos_blocked(Vector2(15.0, 15.0)))
	assert_true(map.get_module_at(Vector2(15.0, 15.0)).is_empty())
	map.free()


func test_paredes_puentes_y_plataformas_no_son_modulos() -> void:
	var map = MapAreaScript.new()
	assert_true(map.get_module_at(Vector2(14.0, 19.0)).is_empty())  # pared
	assert_true(map.get_module_at(Vector2(13.0, 24.0)).is_empty())  # puente
	assert_true(map.get_module_at(Vector2(8.0, 10.0)).is_empty())   # plataforma
	map.free()


func _map_for_modules():
	var map = MapAreaScript.new()
	map.solid_obstacles.clear()  # mapa vacío para ubicar los módulos a mano
	map.player_pos = Vector2(2, 15)
	map.enemy_pos = Vector2(28, 15)
	return map


func test_muro_levanta_modulos_en_fila_perpendicular() -> void:
	var map = _map_for_modules()
	assert_eq(map.build_modules(Vector2(10, 15), 3), 3)
	var ys := []
	for obs in map.solid_obstacles:
		assert_eq(obs["pos"].x, 10.0)
		ys.append(obs["pos"].y)
	ys.sort()
	assert_eq(ys, [14.0, 15.0, 16.0])
	assert_true(map._pos_blocked(Vector2(10, 15)))
	map.free()


func test_muro_no_se_levanta_encima_de_un_actor() -> void:
	var map = _map_for_modules()
	assert_eq(map.build_modules(Vector2(28, 15), 1), 0)
	map.free()


func test_romper_varios_modulos_pegados() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 3)
	map.build_modules(Vector2(20, 15), 1)  # lejos: no está pegado
	var middle: Dictionary = map.get_module_at(Vector2(10, 15))
	assert_eq(map.break_modules(middle, 5), 3)
	assert_eq(map.solid_obstacles.size(), 1)
	map.free()


func test_golpear_modulo_choca_al_enemigo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.solid_obstacles[0]
	var result: Dictionary = map.slide_module(module, Vector2.RIGHT, 30.0)
	assert_eq(result["hit"], "enemy")
	assert_lt(result["pos"].x, 28.0 - map._enemy_shadow_radius)
	map.free()


func test_golpear_modulo_sin_choque_recorre_su_distancia() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	var result: Dictionary = map.slide_module(map.solid_obstacles[0], Vector2.RIGHT, 5.0)
	assert_eq(result["hit"], "")
	assert_almost_eq(result["pos"].x, 15.0, 0.001)
	map.free()


func test_golpear_modulo_se_frena_en_otro_obstaculo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.solid_obstacles[0]
	map.build_modules(Vector2(14, 15), 1)
	var result: Dictionary = map.slide_module(module, Vector2.RIGHT, 10.0)
	assert_eq(result["hit"], "")
	assert_lt(result["pos"].x, 13.0 + 0.001)
	map.free()


func test_derrumbe_tira_solo_los_modulos_pegados_al_enemigo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(26.6, 15), 1)  # pegado al enemigo (28, 15)
	map.build_modules(Vector2(28, 13.6), 1)  # pegado
	map.build_modules(Vector2(24, 15), 1)    # lejos
	assert_eq(map.modules_adjacent_to_enemy().size(), 2)
	assert_eq(map.collapse_modules_on_enemy(), 2)
	assert_eq(map.solid_obstacles.size(), 1)
	map.free()


func test_muro_que_pasa_por_encima_del_enemigo_queda_pegado_para_derrumbe() -> void:
	var map = _map_for_modules()
	map.player_pos = Vector2(28, 25)
	# Muro de 5 que cruza al enemigo (28, 15): los del medio se saltean.
	map.build_modules(Vector2(28.5, 15), 5)
	assert_lt(map.solid_obstacles.size(), 5)
	assert_eq(map.modules_adjacent_to_enemy().size(), 2)
	map.free()


func test_lanzar_modulo_le_cae_al_enemigo_y_se_rompe() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(4, 15), 1)
	var module: Dictionary = map.solid_obstacles[0]
	var hits: Dictionary = map.throw_module(module, Vector2(27.5, 15))
	assert_true(hits["enemy"])
	assert_false(hits["player"])
	assert_true(map.solid_obstacles.is_empty())
	map.free()


func test_lanzar_modulo_al_vacio_no_le_pega_a_nadie() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(4, 15), 1)
	var hits: Dictionary = map.throw_module(map.solid_obstacles[0], Vector2(15, 5))
	assert_false(hits["enemy"])
	assert_false(hits["player"])
	map.free()


# ── Hechizos ──────────────────────────────────────────────────────────────────

func test_set_enemy_status_respeta_la_resistencia() -> void:
	var s := CombatState.new()
	s.enemy_status_reduction = 1
	assert_eq(s.set_enemy_status("blind", 3), 2)
	assert_eq(s.enemy_blinded_turns, 2)
	assert_eq(s.set_enemy_status("inexistente", 3), 0)


func test_curar_no_pasa_el_maximo() -> void:
	var s := CombatState.new()
	s.player_max_hp = 200
	s.player_hp = 150
	assert_eq(s.heal_player(80), 50)
	assert_eq(s.player_hp, 200)


func test_chispa_convierte_grasa_en_fuego_y_escarcha_agua_en_hielo() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "grease")
	map.place_puddle(Vector2(20, 10), 1.0, "wet")
	assert_eq(map.convert_puddles(Vector2(10, 10), 1.0, ["grease", "vine"], "fire"), 1)
	assert_eq(map.convert_puddles(Vector2(20, 10), 1.0, ["wet"], "ice"), 1)
	var effects: Array = map.puddle_zones.map(func(z): return z["effect"])
	assert_eq(effects, ["fire", "ice"])
	map.free()


func test_descarga_se_propaga_por_el_agua() -> void:
	var map = _map_for_modules()
	map.enemy_pos = Vector2(10, 25)
	map.place_puddle(Vector2(10, 22), 3.5, "wet")  # el enemigo está parado en el agua
	var water: Array = map.puddles_on_segment(Vector2(2, 20), Vector2(14, 20), ["wet"])
	assert_eq(water.size(), 1)
	assert_true(map.is_pos_in_zones(map.enemy_pos, water))
	assert_false(map.segment_hits_enemy(Vector2(2, 20), Vector2(14, 20)))
	map.free()


func test_aliento_alcanza_en_cono() -> void:
	var map = _map_for_modules()
	map.enemy_pos = Vector2(6, 16)
	assert_true(map.is_enemy_in_cone(map.player_pos, Vector2.RIGHT, 5.0, 30.0))
	assert_false(map.is_enemy_in_cone(map.player_pos, Vector2.LEFT, 5.0, 30.0))
	assert_false(map.is_enemy_in_cone(map.player_pos, Vector2.RIGHT, 2.0, 30.0))
	map.free()


func test_meteoro_cae_al_resolver_y_le_pega_a_quien_siga_ahi() -> void:
	var map = _map_for_modules()
	map.place_delayed_zone(map.enemy_pos, 1.5, 120, "Meteoro")
	map.place_delayed_zone(Vector2(15, 5), 1.5, 120, "Meteoro")
	var hits: Array = map.resolve_delayed_zones()
	assert_eq(hits.size(), 2)
	assert_true(hits[0]["enemy"])
	assert_false(hits[1]["enemy"])
	assert_true(map.delayed_zones.is_empty())
	map.free()


func test_hechizo_retardado_cae_a_las_2_rondas_y_deja_su_charco() -> void:
	var map = _map_for_modules()
	map.place_delayed_zone(map.enemy_pos, 1.5, 120, "Meteoro", 2, "fire", 3)
	assert_true(map.resolve_delayed_zones().is_empty())  # falta una ronda
	assert_eq(map.delayed_zones.size(), 1)
	assert_true(map.puddle_zones.is_empty())
	var hits: Array = map.resolve_delayed_zones()
	assert_eq(hits.size(), 1)
	assert_true(hits[0]["enemy"])
	assert_eq(hits[0]["tick_damage"], 30)  # 25 % del daño
	assert_eq(map.puddle_zones.size(), 1)
	assert_eq(map.puddle_zones[0]["effect"], "fire")
	assert_eq(map.puddle_zones[0]["turns"], 3)
	assert_eq(map.puddle_zones[0]["damage"], 30)
	map.free()


func test_hechizo_retardado_sin_efecto_no_deja_charco() -> void:
	var map = _map_for_modules()
	map.place_delayed_zone(map.enemy_pos, 1.5, 50, "Test")
	map.resolve_delayed_zones()
	assert_true(map.puddle_zones.is_empty())
	map.free()


func test_impacto_de_charco_aplica_su_estado_y_danio_por_turno() -> void:
	var s := CombatState.new()
	assert_eq(s.puddle_impact_on_enemy("fire", 30), ["burn", 3])
	assert_eq(s.enemy_burn_damage, 30)
	assert_eq(s.puddle_impact_on_player("ice", 0), ["freeze", 2])
	assert_eq(s.player_frozen_turns, 2)
	assert_eq(s.puddle_impact_on_enemy("dark_smoke", 0), [])


func test_parpadeo_no_aparece_en_obstaculos_ni_encima_del_enemigo() -> void:
	var map = _map_for_modules()
	map.build_modules(Vector2(10, 15), 1)
	assert_false(map.can_blink_to(Vector2(10, 15)))
	assert_false(map.can_blink_to(map.enemy_pos))
	assert_true(map.can_blink_to(Vector2(10, 5)))
	map.blink_player_to(Vector2(10, 5))
	assert_eq(map.player_pos, Vector2(10, 5))
	map.free()


func test_trasladar_charco_conserva_efecto_rondas_y_danio() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "fire", 2, 45)
	var moved: Dictionary = map.move_puddle(map.get_puddle_at(Vector2(10, 10)), Vector2(20, 12))
	assert_eq(map.puddle_zones.size(), 1)
	assert_eq(moved["pos"], Vector2(20, 12))
	assert_eq(moved["effect"], "fire")
	assert_eq(moved["turns"], 2)
	assert_eq(moved["damage"], 45)
	assert_eq(map._puddle_visuals.size(), 1)
	map.free()


func test_trasladar_charco_se_lleva_su_zona_combinada() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "blood", 0, 20)
	map.place_puddle(Vector2(11, 10), 1.0, "ice")
	assert_eq(map.puddle_zones.size(), 3)  # sangre, lente de hielo sangriento, hielo
	map.move_puddle(map.get_puddle_at(Vector2(11.8, 10)), Vector2(20, 20))
	var effects: Array = map.puddle_zones.map(func(z): return z["effect"])
	assert_eq(effects, ["blood", "ice"])
	assert_true(map.puddle_zones[0]["excl"].is_empty())
	map.free()


func test_las_zonas_combinadas_no_se_pueden_elegir_para_trasladar() -> void:
	var map = _map_for_modules()
	map.place_puddle(Vector2(10, 10), 1.0, "blood")
	map.place_puddle(Vector2(11, 10), 1.0, "ice")
	var zone: Dictionary = map.get_puddle_at(Vector2(10.5, 10))
	assert_false(zone.get("lens", false))
	map.free()


func test_set_enemy_status_sangrado() -> void:
	var s := CombatState.new()
	assert_eq(s.set_enemy_status("bleed", 4), 4)
	assert_eq(s.enemy_bleeding_turns, 4)


# ── Trepar árbol ──────────────────────────────────────────────────────────────

func test_hay_arboles_para_trepar() -> void:
	var map = MapAreaScript.new()
	assert_eq(map.get_tree_at(Vector2(5.0, 24.0)).get("type"), "tree")
	assert_true(map.get_tree_at(Vector2(15.0, 15.0)).is_empty())  # piedra, no árbol
	assert_true(map._pos_blocked(Vector2(5.0, 24.0)))
	map.free()


func test_caer_del_arbol_sobre_el_enemigo_queda_pegado_a_el() -> void:
	var map = MapAreaScript.new()
	map.player_pos = Vector2(5.0, 25.4)
	map.enemy_pos = Vector2(8.0, 24.0)
	var tree: Dictionary = map.get_tree_at(Vector2(5.0, 24.0))
	map.climb_tree(tree, map.enemy_pos)
	assert_true(map.is_player_in_tree())
	assert_true(map.drop_from_tree(map.enemy_pos))
	assert_false(map.is_player_in_tree())
	assert_almost_eq(map.player_pos.distance_to(map.enemy_pos), map.MIN_SEPARATION, 0.01)
	map.free()


func test_caer_del_arbol_en_un_lugar_libre() -> void:
	var map = MapAreaScript.new()
	map.player_pos = Vector2(5.0, 25.4)
	var tree: Dictionary = map.get_tree_at(Vector2(5.0, 24.0))
	map.climb_tree(tree, Vector2(8.0, 26.0))
	assert_false(map.drop_from_tree(Vector2(8.0, 26.0)))
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
	assert_eq(pa.pending_move_index, -1)
	assert_eq(_map.start_move_selection_calls, 0)


func _map_with_tree(tree_pos := Vector2(10, 15)):
	var map = _map_for_modules()
	map.solid_obstacles.append({"pos": tree_pos, "radius": 0.6, "type": "tree"})
	return map


func test_talar_arbol_deja_un_tronco_tirado() -> void:
	var map = _map_with_tree()
	var tree: Dictionary = map.get_tree_at(Vector2(10, 15))
	var result: Dictionary = map.fell_tree(tree, Vector2.RIGHT)
	assert_false(result["enemy_hit"])
	assert_true(map.get_tree_at(Vector2(10, 15)).is_empty())
	var segments: Array = map.solid_obstacles.filter(func(o): return o.has("log_id"))
	assert_eq(segments.size(), map.LOG_SEGMENTS)
	assert_true(map._pos_blocked(Vector2(10.9, 15)))
	assert_true(map.has_line_of_sight(Vector2(10.9, 13), Vector2(10.9, 17)))  # es bajo: se ve por encima
	map.free()


func test_el_tronco_se_rompe_entero_con_una_carta() -> void:
	var map = _map_with_tree()
	map.fell_tree(map.get_tree_at(Vector2(10, 15)), Vector2.RIGHT)
	var piece: Dictionary = map.get_module_at(Vector2(10.9, 15))
	assert_eq(map.break_modules(piece, 1), map.LOG_SEGMENTS)
	assert_true(map.solid_obstacles.is_empty())
	map.free()


func test_arbol_que_cae_sobre_el_enemigo_le_pega() -> void:
	var map = _map_with_tree(Vector2(26.2, 15))
	var result: Dictionary = map.fell_tree(map.get_tree_at(Vector2(26.2, 15)), Vector2.RIGHT)
	assert_true(result["enemy_hit"])
	map.free()


func test_talar_el_arbol_con_el_jugador_arriba_lo_tira() -> void:
	var map = _map_with_tree()
	var knocked := []
	map.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	map.climb_tree(map.get_tree_at(Vector2(10, 15)), Vector2(12, 12))
	map.fell_tree(map.get_tree_at(Vector2(10, 15)), Vector2.RIGHT)
	assert_eq(knocked, [false])
	assert_false(map.is_player_in_tree())
	map.free()


func test_charco_de_fuego_prende_el_arbol_y_se_consume() -> void:
	var map = _map_with_tree()
	var knocked := []
	map.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	var tree: Dictionary = map.get_tree_at(Vector2(10, 15))
	map.climb_tree(tree, Vector2(12, 12))
	map.place_puddle(Vector2(10.5, 16), 1.0, "fire", 3, 30)
	assert_true(map.is_tree_burning(tree))
	assert_eq(knocked, [true])
	map.tick_trees()
	assert_false(map.get_tree_at(Vector2(10, 15)).is_empty())
	map.tick_trees()
	assert_true(map.get_tree_at(Vector2(10, 15)).is_empty())
	map.free()


func test_otros_charcos_no_prenden_arboles() -> void:
	var map = _map_with_tree()
	map.place_puddle(Vector2(10.5, 16), 1.0, "wet")
	assert_false(map.is_tree_burning(map.get_tree_at(Vector2(10, 15))))
	map.free()


func test_golpear_un_modulo_contra_el_arbol_tira_al_de_arriba() -> void:
	var map = _map_with_tree(Vector2(14, 15))
	var knocked := []
	map.player_knocked_off_tree.connect(func(burning): knocked.append(burning))
	map.climb_tree(map.get_tree_at(Vector2(14, 15)), Vector2(12, 12))
	map.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.get_module_at(Vector2(10, 15))
	var result: Dictionary = map.slide_module(module, Vector2.RIGHT, 10.0)
	assert_false(result["tree"].is_empty())
	assert_eq(knocked, [false])
	map.free()


func test_agua_y_hielo_apagan_arboles_en_llamas() -> void:
	var map = _map_with_tree()
	var tree: Dictionary = map.get_tree_at(Vector2(10, 15))
	map.ignite_trees_in_circle(Vector2(10, 15), 1.0)
	assert_true(map.is_tree_burning(tree))
	map.place_puddle(Vector2(10.5, 16), 1.0, "wet")
	assert_false(map.is_tree_burning(tree))
	map.ignite_trees_in_circle(Vector2(10, 15), 1.0)
	assert_eq(map.extinguish_trees_in_circle(Vector2(10, 15), 1.0), 1)
	map.free()


func test_el_rayo_se_frena_en_el_primer_arbol() -> void:
	var map = _map_with_tree(Vector2(8, 15))
	var rod: Dictionary = map.first_tree_on_segment(Vector2(2, 15), Vector2(20, 15))
	assert_false(rod.is_empty())
	assert_lt(rod["t"], 0.5)
	assert_true(map.first_tree_on_segment(Vector2(2, 10), Vector2(20, 10)).is_empty())
	map.free()


func test_charco_de_planta_junto_a_un_arbol_es_mas_grande() -> void:
	var map = _map_with_tree()
	map.place_puddle(Vector2(11.5, 15), 1.0, "vine")
	map.place_puddle(Vector2(25, 5), 1.0, "vine")
	assert_almost_eq(float(map.puddle_zones[0]["radius"]), 1.0 * map.TREE_VINE_RADIUS_MULT, 0.001)
	assert_almost_eq(float(map.puddle_zones[1]["radius"]), 1.0, 0.001)
	map.free()


func test_el_fuego_del_arbol_se_propaga_por_la_planta_a_otro_arbol() -> void:
	var map = _map_with_tree(Vector2(10, 15))
	map.solid_obstacles.append({"pos": Vector2(13, 15), "radius": 0.6, "type": "tree"})
	map.place_puddle(Vector2(11.5, 15), 1.0, "vine")  # une los dos árboles
	map.ignite_trees_in_circle(Vector2(10, 15), 0.5)
	assert_eq(map.puddle_zones[0]["effect"], "fire")
	assert_true(map.is_tree_burning(map.get_tree_at(Vector2(13, 15))))
	map.free()


func test_ariete_empuja_el_tronco_entero() -> void:
	var map = _map_with_tree(Vector2(10, 10))
	map.fell_tree(map.get_tree_at(Vector2(10, 10)), Vector2.RIGHT)
	var before: Array = map.solid_obstacles.map(func(o): return o["pos"])
	map.slide_module(map.get_module_at(Vector2(10, 10)), Vector2.DOWN, 3.0)
	var after: Array = map.solid_obstacles.map(func(o): return o["pos"])
	for i in before.size():
		assert_almost_eq((after[i] - before[i]).y, 3.0, 0.001)
		assert_almost_eq((after[i] - before[i]).x, 0.0, 0.001)
	map.free()


func test_caer_del_arbol_en_un_charco_te_aplica_su_efecto() -> void:
	var s := CombatState.new()
	s.player_in_tree = true
	_map.puddle_effects_result = {"poison": true}
	_map.puddle_damage_result = {"poison": 14}
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, Callable(), _dmg_player_callable(s), func() -> bool: return false)
	await pa.player_falls_from_tree(false)
	assert_gt(s.player_poison_stacks, 0)
	assert_eq(s.player_poison_damage, 14)


func test_confirmar_deja_fija_la_vista_previa_en_el_clic() -> void:
	var map = MapAreaScript.new()
	map._last_click_pos = Vector2(7, 8)
	map.lock_hover_at_last_click()
	assert_true(map._hover_locked)
	map.unlock_hover()
	assert_false(map._hover_locked)
	map.free()


func test_cancelar_cierra_el_popup_de_confirmar() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	var hidden := [0]
	pa.confirm_popup_hide_requested.connect(func(): hidden[0] += 1)
	pa.pending_cell = Vector2(3, 3)
	pa.cancel_selection()
	assert_eq(hidden[0], 1)
	assert_eq(pa.pending_cell, Vector2(-1, -1))


func test_caerse_de_un_arbol_en_llamas_hace_danio_y_prende_fuego() -> void:
	var s := CombatState.new()
	s.player_in_tree = true
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, Callable(), _dmg_player_callable(s), func() -> bool: return false)
	var hp := s.player_hp
	await pa.player_falls_from_tree(true)
	assert_false(s.player_in_tree)
	assert_eq(s.player_hp, hp - CombatPlayerActions.TREE_FALL_DAMAGE)
	assert_gt(s.player_burning_turns, 0)


func test_charcos_cuestan_mp() -> void:
	for card: CardData in CardDatabase.cards_by_id.values():
		for line: CardActionLine in card.top.lines + card.bottom.lines:
			if line.card_type == "puddle":
				assert_gt(line.mp_cost, 0, card.id)


func test_danio_de_charco_a_lo_largo_de_un_segmento() -> void:
	var map = MapAreaScript.new()
	map.place_puddle(Vector2(5, 5), 1.0, "fire", 3, 40)
	map.place_puddle(Vector2(5, 5), 1.0, "wet")
	assert_eq(map.get_puddle_damage_along(Vector2(3, 5), Vector2(7, 5)), {"fire": 40})
	assert_eq(map.get_puddle_damage_along(Vector2(20, 20), Vector2(21, 20)), {})
	map.free()


# ── CombatPlayerActions — overwatch ───────────────────────────────────────────

func test_execute_overwatch_activa_estado_con_datos_de_la_carta() -> void:
	var s := CombatState.new()
	var card := _make_card("overwatch", 0, 15)
	card.card_range = 4
	s.turn_actions.append(card)
	_map.player_pos = Vector2(1.0, 1.0)
	var pa := _make_player_actions(s)
	pa.pending_overwatch_index = 0
	pa._execute_overwatch(Vector2(1.0, 0.0))
	assert_true(s.player_overwatch_active)
	assert_eq(s.player_overwatch_damage, 15)
	assert_almost_eq(s.player_overwatch_range, 4 * CombatGrid.CELL, 0.0001)  # 4 casillas
	assert_eq(s.player_overwatch_origin, Vector2(1.0, 1.0))
	assert_eq(s.player_overwatch_dir, Vector2(1.0, 0.0))


func test_jugar_otra_carta_cancela_overwatch_activo() -> void:
	var s := CombatState.new()
	s.player_overwatch_active = true
	s.turn_actions.append(_make_card("block", 5))
	var pa := _make_player_actions(s)
	pa.play_card(0)
	assert_false(s.player_overwatch_active)
	assert_eq(_map.clear_overwatch_zone_calls, 1)


# ── CombatPlayerActions — la acción se gasta antes de la animación ──────────

func test_confirm_range_attack_gasta_la_accion_antes_del_danio() -> void:
	# Durante la animación de daño el jugador puede elegir otra mitad o terminar
	# el turno; la acción ya tiene que estar fuera de state.turn_actions.
	var s := CombatState.new()
	s.turn_actions.append(_make_card("melee_attack", 0, 6))
	var size_during_damage := [-1]
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, func(amount: int, _skip := false, _type := CombatState.FISICO) -> void:
		size_during_damage[0] = s.turn_actions.size()
		s.turn_actions.clear()  # simula "fin de turno" durante la animación
		s.enemy_hp -= amount, Callable(), func() -> bool: return false)
	pa.pending_attack_index = 0
	pa.pending_attack_range = 1

	await pa._confirm_range_attack()

	assert_eq(size_during_damage[0], 0)
	assert_eq(s.enemy_hp, s.enemy_max_hp - 6)


func test_encantar_arma_vuelve_magico_el_proximo_ataque_y_suma_danio() -> void:
	var s := CombatState.new()
	s.player_enchant_damage = 20
	s.player_enchant_status = "burn"
	s.turn_actions.append(_make_card("melee_attack", 0, 6))
	var hits := []
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, func(amount: int, _skip := false, type := CombatState.FISICO) -> void:
		hits.append([amount, type]), Callable(), func() -> bool: return false)
	pa.pending_attack_index = 0
	pa.pending_attack_range = 1
	await pa._confirm_range_attack()
	assert_eq(hits, [[26, CombatState.MAGICO]])
	assert_eq(s.player_enchant_damage, 0)
	assert_gt(s.enemy_burning_turns, 0)


# ── Cartas de monstruo ────────────────────────────────────────────────────────

func _make_monster_action(type: String, value: int = 0, range_mod: int = 0) -> MonsterCardAction:
	var a := MonsterCardAction.new()
	a.type = type
	a.value = value
	a.range_modifier = range_mod
	return a


func _make_monster_card(initiative: int, actions: Array) -> MonsterCard:
	var c := MonsterCard.new()
	c.card_name = "Test"
	c.initiative = initiative
	c.actions.assign(actions)
	return c


func _make_monster_deck(cards: Array, base_move := 63, base_attack := 6, base_range := 0) -> MonsterDeck:
	var d := MonsterDeck.new()
	d.base_move = base_move
	d.base_attack = base_attack
	d.base_range = base_range
	d.cards.assign(cards)
	return d


func _make_card_ai(s: CombatState, deck: MonsterDeck) -> CombatEnemyAI:
	var ai := _make_ai_full(s)
	ai.set_monster_deck(deck)
	ai.action_delay = 0.0
	return ai


func test_draw_card_toma_la_iniciativa_de_la_carta() -> void:
	var s := CombatState.new()
	var ai := _make_card_ai(s, _make_monster_deck([_make_monster_card(19, [])]))
	ai.draw_card()
	assert_eq(ai.initiative, 19)


func test_draw_card_no_repite_hasta_usar_todo_el_mazo() -> void:
	var s := CombatState.new()
	var cards := [_make_monster_card(10, []), _make_monster_card(20, []), _make_monster_card(30, [])]
	var ai := _make_card_ai(s, _make_monster_deck(cards))
	var seen := []
	for i in 3:
		seen.append(ai.draw_card())
	for c in cards:
		assert_true(seen.has(c))


func test_draw_card_sin_mazo_devuelve_null_y_mantiene_iniciativa() -> void:
	var s := CombatState.new()
	var ai := _make_ai_full(s)
	ai.initiative = 50
	assert_null(ai.draw_card())
	assert_eq(ai.initiative, 50)


func test_carta_ataque_en_alcance_hace_base_mas_modificador() -> void:
	var s := CombatState.new()
	_map.enemy_pos = Vector2(1.0, 0.0)  # a 1 del jugador: dentro del cuerpo a cuerpo
	var card := _make_monster_card(20, [_make_monster_action("attack", 2)])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	var hp := s.player_hp
	await ai.execute_card(card)
	assert_eq(s.player_hp, hp - 8)  # base 6 + 2


func test_contraataque_devuelve_el_golpe_cuerpo_a_cuerpo() -> void:
	var s := CombatState.new()
	s.player_counter_damage = 25
	_map.enemy_pos = Vector2(1.0, 0.0)
	var card := _make_monster_card(20, [_make_monster_action("attack", 2)])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	var enemy_hp := s.enemy_hp
	await ai.execute_card(card)
	assert_eq(s.enemy_hp, enemy_hp - 25)


func test_contraataque_no_alcanza_ataques_a_distancia() -> void:
	var s := CombatState.new()
	s.player_counter_damage = 25
	_map.enemy_pos = Vector2(7.0, 0.0)
	var card := _make_monster_card(20, [_make_monster_action("attack", 0, -13)])
	var ai := _make_card_ai(s, _make_monster_deck([card], 50, 4, 100))
	var enemy_hp := s.enemy_hp
	await ai.execute_card(card)
	assert_eq(s.enemy_hp, enemy_hp)


func test_contraataque_se_reinicia_cada_ronda() -> void:
	var s := CombatState.new()
	s.player_counter_damage = 25
	var dm := CombatDeckManager.new()
	dm.setup(s)
	dm.reset_turn(0)
	assert_eq(s.player_counter_damage, 0)


# ── Resistencia a estados ────────────────────────────────────────────────────

func test_status_turns_resta_la_reduccion_sin_bajar_de_1() -> void:
	var s := CombatState.new()
	s.player_status_reduction = 2
	s.enemy_status_reduction = -1
	assert_eq(s.status_turns(4, true), 2)
	assert_eq(s.status_turns(2, true), 1)
	assert_eq(s.status_turns(3, false), 4)


func test_enemigo_resistente_se_prende_fuego_menos_turnos() -> void:
	var s := CombatState.new()
	s.enemy_status_reduction = 1
	var ai := _make_ai(s)
	_map.puddle_effects_result = {"fire": true}
	ai._apply_enemy_zone_effects(Vector2.ZERO)
	assert_eq(s.enemy_burning_turns, 2)


func test_carta_ataque_fuera_de_alcance_no_hace_danio() -> void:
	var s := CombatState.new()
	_map.enemy_pos = Vector2(10.0, 0.0)
	var card := _make_monster_card(20, [_make_monster_action("attack", 0)])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	var hp := s.player_hp
	await ai.execute_card(card)
	assert_eq(s.player_hp, hp)


func test_carta_ataque_a_distancia_usa_rango_base_mas_modificador() -> void:
	var s := CombatState.new()
	_map.enemy_pos = Vector2(7.0, 0.0)  # 5,7 entre bordes
	var card := _make_monster_card(20, [_make_monster_action("attack", 0, -13)])
	var ai := _make_card_ai(s, _make_monster_deck([card], 50, 4, 100))  # 100 - 13 = 87 casillas = 6,96
	var hp := s.player_hp
	await ai.execute_card(card)
	assert_eq(s.player_hp, hp - 4)


func test_carta_mover_se_saltea_si_ya_esta_al_alcance_del_ataque() -> void:
	var s := CombatState.new()
	_map.enemy_pos = Vector2(1.0, 0.0)
	var card := _make_monster_card(20, [_make_monster_action("move"), _make_monster_action("attack")])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	await ai.execute_card(card)
	assert_eq(_map.move_enemy_toward_calls, 0)


func test_carta_mover_se_acerca_si_esta_lejos() -> void:
	var s := CombatState.new()
	_map.enemy_pos = Vector2(10.0, 0.0)
	var card := _make_monster_card(20, [_make_monster_action("move"), _make_monster_action("attack")])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	await ai.execute_card(card)
	assert_eq(_map.move_enemy_toward_calls, 1)


func test_carta_bloqueo_y_curacion() -> void:
	var s := CombatState.new()
	s.enemy_hp = s.enemy_max_hp - 2
	var card := _make_monster_card(20, [_make_monster_action("block", 3), _make_monster_action("heal", 5)])
	var ai := _make_card_ai(s, _make_monster_deck([card]))
	await ai.execute_card(card)
	assert_eq(s.enemy_block, 3)
	assert_eq(s.enemy_hp, s.enemy_max_hp)  # la curación no pasa el máximo


func test_mazos_de_monstruo_tienen_cartas_con_acciones() -> void:
	for path in ["res://data/enemies/monster_decks/bruto.tres", "res://data/enemies/monster_decks/arquero.tres"]:
		var deck: MonsterDeck = load(path)
		assert_false(deck.cards.is_empty(), path)
		for card in deck.cards:
			assert_false(card.actions.is_empty(), "%s: %s sin acciones" % [path, card.card_name])
