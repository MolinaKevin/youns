extends "res://tests/helpers/combat_test_case.gd"

## Pruebas de selección, confirmación y resolución de acciones del jugador.


func test_setup_acepta_el_contrato_combat_map_area() -> void:
	var state := CombatState.new()
	var map := CombatMapArea.new()
	var actions := CombatPlayerActions.new()

	actions.setup(state, map, Callable(), Callable(), Callable())

	assert_eq(actions.map_area, map)
	map.free()


# ── Block card — confirm_self_action ──────────────────────────────────────────

func test_execute_puddle_usa_el_effect_y_rango_de_la_carta() -> void:
	var s := CombatState.new()
	var card := _make_card("puddle")
	card.puddle_effect = "fire"
	card.primary_base_modules = 2
	s.turn_actions.append(card)
	var pa := _make_player_actions(s)
	pa.play_card(0)
	pa.execute_selection_at(Vector2(4.0, 2.0))
	assert_eq(_map.place_puddle_calls.size(), 1)
	assert_eq(_map.place_puddle_calls[0]["effect"], "fire")
	assert_almost_eq(_map.place_puddle_calls[0]["radius"], card.primary_range_cells() * CombatGrid.CELL, 0.0001)
	assert_eq(_map.place_puddle_calls[0]["pos"], Vector2(4.0, 2.0))


func test_execute_puddle_pasa_duracion_y_danio() -> void:
	var s := CombatState.new()
	var card := _make_card("puddle")
	card.puddle_effect = "fire"
	card.primary_base_modules = 2
	card.duration = 4
	card.damage = 45
	s.turn_actions.append(card)
	var pa := _make_player_actions(s)
	pa.play_card(0)
	pa.execute_selection_at(Vector2(4.0, 2.0))
	assert_eq(_map.place_puddle_calls[0]["turns"], 4)
	assert_eq(_map.place_puddle_calls[0]["damage"], 45)


# ── CombatPlayerActions — overwatch ───────────────────────────────────────────

func test_execute_overwatch_activa_estado_con_datos_de_la_carta() -> void:
	var s := CombatState.new()
	var card := _make_card("overwatch", 0, 15)
	card.primary_base_modules = 4
	s.turn_actions.append(card)
	_map.player_pos = Vector2(1.0, 1.0)
	var pa := _make_player_actions(s)
	pa.play_card(0)
	pa.select_position(Vector2(2.0, 1.0))
	pa.execute_selection_at(Vector2(1.0, 0.0))
	assert_true(s.player_overwatch_active)
	assert_eq(s.player_overwatch_damage, 15)
	assert_almost_eq(s.player_overwatch_range, card.primary_range_cells() * CombatGrid.CELL, 0.0001)
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
	pa.start_range_attack_selection(0, s.turn_actions[0], 1)
	await pa.execute_selection_at_async(Vector2.ZERO)

	assert_eq(size_during_damage[0], 0)
	assert_eq(s.enemy_hp, s.enemy_max_hp - 6)


func test_range_attack_suelta_la_seleccion_antes_de_refrescar_la_mano() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("melee_attack", 0, 6))
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, func(_amount: int, _skip := false, _type := CombatState.FISICO) -> void: pass,
		Callable(), func() -> bool: return false)
	var pending_during_refresh := [true]
	pa.hand_refresh_requested.connect(func(): pending_during_refresh[0] = pa.has_pending_selection())
	pa.start_range_attack_selection(0, s.turn_actions[0], 1)
	await pa.execute_selection_at_async(Vector2.ZERO)

	assert_false(pending_during_refresh[0])
	assert_false(pa.has_pending_selection())


func test_encantar_arma_vuelve_magico_el_proximo_ataque_y_suma_danio() -> void:
	var s := CombatState.new()
	s.player_enchant_damage = 20
	s.player_enchant_status = "burn"
	s.turn_actions.append(_make_card("melee_attack", 0, 6))
	var hits := []
	var pa := CombatPlayerActions.new()
	pa.setup(s, _map, func(amount: int, _skip := false, type := CombatState.FISICO) -> void:
		hits.append([amount, type]), Callable(), func() -> bool: return false)
	pa.start_range_attack_selection(0, s.turn_actions[0], 1)
	await pa.execute_selection_at_async(Vector2.ZERO)
	assert_eq(hits, [[26, CombatState.MAGICO]])
	assert_eq(s.player_enchant_damage, 0)
	assert_gt(s.enemy_burning_turns, 0)


# ── trap ──────────────────────────────────────────────────────────────────────

func test_trap_place_coloca_la_trampa_y_consume_la_carta() -> void:
	var s := CombatState.new()
	s.turn_actions.append(_make_card("trap_place", 0, 20))
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(Vector2(1.0, 0.0))
	pa.confirm_selection()
	assert_eq(_map.place_trap_calls.size(), 1)
	assert_eq(s.turn_actions.size(), 0)


# ── grenade ───────────────────────────────────────────────────────────────────

func test_grenade_le_pega_al_enemigo_y_consume_la_carta() -> void:
	var s := CombatState.new()
	var c := _make_card("grenade", 0, 30)
	c.card_range = 500
	c.throw_range = 500
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(_map.enemy_pos)
	pa.confirm_selection()
	assert_eq(s.turn_actions.size(), 0)
	assert_lt(s.enemy_hp, s.enemy_max_hp)
	# La granada espera 0.6s reales antes de cerrar su vista previa (ver
	# CombatGrenadeAction.execute) — dejamos que termine antes del próximo test.
	await get_tree().create_timer(0.7).timeout


# ── rock_jump ─────────────────────────────────────────────────────────────────

func test_rock_jump_cae_sobre_el_enemigo_hace_danio() -> void:
	var s := CombatState.new()
	var c := _make_card("rock_jump", 0, 40)
	c.card_range = 500
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(_map.enemy_pos)  # fase 0: el mock siempre "encuentra" una piedra
	pa.select_position(_map.enemy_pos)  # fase 1: aterrizar sobre el enemigo
	pa.confirm_selection()
	assert_eq(s.turn_actions.size(), 0)
	assert_lt(s.enemy_hp, s.enemy_max_hp)


func test_rock_jump_sin_pegarle_al_enemigo_no_hace_danio() -> void:
	var s := CombatState.new()
	var c := _make_card("rock_jump", 0, 40)
	c.card_range = 500
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(Vector2(5.0, 0.0))
	pa.select_position(Vector2(-5.0, 0.0))  # lejos del enemigo (10, 0)
	pa.confirm_selection()
	assert_eq(s.turn_actions.size(), 0)
	assert_eq(s.enemy_hp, s.enemy_max_hp)


# ── push / pull / anchor ──────────────────────────────────────────────────────

func test_pull_acerca_al_enemigo_y_consume_la_carta() -> void:
	var s := CombatState.new()
	var c := _make_card("pull", 0, 0)
	c.card_range = 500
	c.throw_range = 500
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(_map.enemy_pos)  # pull no tiene segunda fase
	pa.confirm_selection()
	# push/pull animan de verdad (señales de map_area, no un Callable):
	# hay que dejar correr unos frames para que la cadena de awaits resuelva.
	for i in 10:
		await get_tree().process_frame
	assert_eq(s.turn_actions.size(), 0)
	assert_eq(_map.push_enemy_to_calls.size(), 1)
	assert_eq(_map.push_enemy_to_calls[0], _map.player_pos)


# ── módulos ───────────────────────────────────────────────────────────────────

func test_build_levanta_modulos_y_consume_la_carta() -> void:
	var s := CombatState.new()
	var c := _make_card("build", 0, 0)
	c.card_range = 500
	c.module_count = 2
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(Vector2(1.0, 0.0))
	pa.confirm_selection()
	for i in 5:
		await get_tree().process_frame
	assert_eq(_map.build_modules_calls.size(), 1)
	assert_eq(_map.build_modules_calls[0]["count"], 2)
	assert_eq(s.turn_actions.size(), 0)


# ── hechizos ──────────────────────────────────────────────────────────────────

func test_blink_teletransporta_al_jugador_y_consume_la_carta() -> void:
	var s := CombatState.new()
	var c := _make_card("blink", 0, 0)
	c.card_range = 500
	c.throw_range = 500
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(Vector2(2.0, 0.0))
	pa.confirm_selection()
	assert_eq(_map.blink_calls.size(), 1)
	assert_eq(_map.blink_calls[0], Vector2(2.0, 0.0))
	assert_eq(s.turn_actions.size(), 0)


func test_delayed_area_marca_la_zona_y_consume_la_carta() -> void:
	var s := CombatState.new()
	var c := _make_card("delayed_area", 0, 50)
	c.card_range = 500
	c.throw_range = 500
	c.delay = 2
	s.turn_actions.append(c)
	var pa := _make_full_player_actions(s)
	pa.play_card(0)
	pa.select_position(Vector2(3.0, 0.0))
	pa.confirm_selection()
	assert_eq(_map.place_delayed_zone_calls.size(), 1)
	assert_eq(_map.place_delayed_zone_calls[0]["damage"], 50)
	assert_eq(s.turn_actions.size(), 0)
