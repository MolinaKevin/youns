extends "res://tests/helpers/combat_test_case.gd"

## Selección, bloqueo y confirmación de acciones del jugador.

func test_block_card_suma_block_amount_al_player_block() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("block", 5))

	var pa := _make_player_actions(s)
	pa.play_card(0)
	pa.execute_selection_at(Vector2.ZERO)

	assert_eq(s.player_block, 5)


func test_block_card_consume_la_accion_del_turno() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("block", 5))

	var pa := _make_player_actions(s)
	pa.play_card(0)
	pa.execute_selection_at(Vector2.ZERO)

	assert_eq(s.turn_actions.size(), 0)


func test_confirm_self_action_con_indice_invalido_no_muta_estado() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.execute_selection_at(Vector2.ZERO)
	assert_eq(s.player_block, 0)


# ── cancel_selection ──────────────────────────────────────────────────────────

func test_cancel_selection_limpia_pending_attack_index() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.start_range_attack_selection(0, _make_card("range_attack", 0, 1))
	pa.cancel_selection()
	assert_false(pa.has_pending_selection())


func test_cancel_selection_limpia_pending_self_index() -> void:
	var s := CombatState.new()
	var pa := _make_player_actions(s)
	pa.start_self_selection(0, _make_card("block", 1))
	pa.cancel_selection()
	assert_false(pa.has_pending_selection())


# ── Block stacking ────────────────────────────────────────────────────────────

func test_dos_cartas_de_bloqueo_acumulan_block_amount() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("block", 5))
	s.turn_actions.append(_make_card("block", 3))

	var pa := _make_player_actions(s)

	pa.play_card(0)
	pa.execute_selection_at(Vector2.ZERO)  # acción 1 consumida, acción 2 queda en índice 0
	pa.play_card(0)
	pa.execute_selection_at(Vector2.ZERO)  # carta 2

	assert_eq(s.player_block, 8)


func test_bloqueo_acumulado_absorbe_daño_combinado() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("block", 4))
	s.turn_actions.append(_make_card("block", 4))

	var pa := _make_player_actions(s)
	pa.play_card(0)
	pa.execute_selection_at(Vector2.ZERO)
	pa.play_card(0)
	pa.execute_selection_at(Vector2.ZERO)

	var hp_inicial := s.player_hp
	s.damage_player(6)  # 6 daño contra 8 de bloqueo → 0 daño
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 2)

# ── Overwatch — emboscada al enemigo ─────────────────────────────────────────

func test_overwatch_activo_dispara_al_enemigo_si_entra_en_el_cono() -> void:
	var s := CombatState.new()
	s.enemy_hp = 20
	s.player_overwatch_active = true
	s.player_overwatch_damage = 7
	_map.overwatch_cone_hit = true
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s).execute_action(action)
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
	await _make_ai_full(s).execute_action(action)
	assert_eq(s.enemy_hp, 20)
	assert_true(s.player_overwatch_active)


# ── CombatPlayerActions — estados bloquean/penalizan movimiento ─────────────

func test_start_move_selection_bloqueada_por_enredado() -> void:
	var s := CombatState.new()
	s.player_entangled_turns = 2
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 3, "Test")
	assert_false(pa.has_pending_selection())
	assert_eq(_map.start_move_selection_calls, 0)


func test_start_move_selection_bloqueada_por_congelado() -> void:
	var s := CombatState.new()
	s.player_frozen_turns = 2
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 3, "Test")
	assert_false(pa.has_pending_selection())
	assert_eq(_map.start_move_selection_calls, 0)


func test_start_move_selection_penaliza_rango_por_mojado_y_engrasado() -> void:
	var s := CombatState.new()
	s.player_wet_turns = 1
	s.player_greasy_turns = 1
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 50, "Test")
	assert_eq(pa.active_selection_range_cells(), 50 - CombatMovePenalty.cells(true, true))


func test_movimiento_termina_si_solo_queda_una_casilla_minima() -> void:
	var s := CombatState.new()
	var card := _make_card("move")
	s.turn_actions.append(card)
	_map.movement_path_cost = 9.0 * CombatGrid.CELL
	var pa := _make_player_actions(s)
	var pending_during_refresh := [true]
	pa.hand_refresh_requested.connect(func(): pending_during_refresh[0] = pa.has_pending_selection())
	pa.start_move_selection("hand", 0, 10, card.name)

	pa.select_position(Vector2(1.0, 0.0))
	pa.confirm_selection()

	assert_false(pa.has_pending_selection())
	assert_false(pending_during_refresh[0])
	assert_eq(s.turn_actions.size(), 0)


func test_movimiento_termina_si_quedan_dos_casillas() -> void:
	var s := CombatState.new()
	var card := _make_card("move")
	s.turn_actions.append(card)
	_map.movement_path_cost = 8.0 * CombatGrid.CELL
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 10, card.name)

	pa.select_position(Vector2(1.0, 0.0))
	pa.confirm_selection()

	assert_false(pa.has_pending_selection())


func test_movimiento_continua_si_quedan_tres_casillas() -> void:
	var s := CombatState.new()
	var card := _make_card("move")
	s.turn_actions.append(card)
	_map.movement_path_cost = 7.0 * CombatGrid.CELL
	var pa := _make_player_actions(s)
	pa.start_move_selection("hand", 0, 10, card.name)

	pa.select_position(Vector2(1.0, 0.0))
	pa.confirm_selection()

	assert_true(pa.has_pending_selection())
	assert_eq(pa.active_selection_range_cells(), 3)


# ── CombatPlayerActions — ceguera reduce rango de ataque ─────────────────────

func test_start_range_attack_selection_reduce_rango_por_cegado() -> void:
	var s := CombatState.new()
	s.player_blinded_turns = 1
	var card := _make_card("range_attack", 0, 8)
	card.card_range = 50
	var pa := _make_player_actions(s)
	pa.start_range_attack_selection(0, card)
	assert_eq(pa.active_selection_range_cells(), CardActionLine.cells_for_modules(CombatPlayerActions.BLINDED_RANGE_MODULES))


func test_start_range_attack_selection_sin_cegado_usa_rango_completo() -> void:
	var s := CombatState.new()
	var card := _make_card("range_attack", 0, 8)
	card.card_range = 5
	var pa := _make_player_actions(s)
	pa.start_range_attack_selection(0, card)
	assert_eq(pa.active_selection_range_cells(), card.primary_range_cells())


# ── CombatPlayerActions — charcos usan el effect/rango de la carta ──────────
