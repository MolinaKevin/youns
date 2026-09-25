extends GutTest

# Tests para CombatDeckManager: draw, discard y reset de turno.
# CombatDeckManager opera sobre un CombatState y no tiene lógica de UI.


func _make_card(id: String) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = id
	return c


func _make_deck(n: int) -> Array:
	var deck := []
	for i in n:
		deck.append(_make_card("card_%d" % i))
	return deck


func _make_manager(p_state: CombatState) -> CombatDeckManager:
	var m := CombatDeckManager.new()
	m.setup(p_state)
	return m


# ── draw_cards ────────────────────────────────────────────────────────────────

func test_draw_cards_agrega_cartas_a_la_mano() -> void:
	var s := CombatState.new()
	s.draw_pile.assign(_make_deck(5))

	_make_manager(s).draw_cards(3)

	assert_eq(s.hand.size(), 3)


func test_draw_cards_reduce_el_draw_pile() -> void:
	var s := CombatState.new()
	s.draw_pile.assign(_make_deck(5))

	_make_manager(s).draw_cards(3)

	assert_eq(s.draw_pile.size(), 2)


func test_draw_cards_con_mazo_vacio_y_descarte_hace_reshuffle() -> void:
	var s := CombatState.new()
	s.discard_pile.assign(_make_deck(4))

	_make_manager(s).draw_cards(2)

	assert_eq(s.hand.size(), 2)


func test_draw_cards_reshuffle_vacia_el_descarte() -> void:
	var s := CombatState.new()
	s.discard_pile.assign(_make_deck(4))

	_make_manager(s).draw_cards(2)

	assert_eq(s.discard_pile.size(), 0)


func test_draw_cards_con_ambos_vacios_no_cambia_la_mano() -> void:
	var s := CombatState.new()

	_make_manager(s).draw_cards(3)

	assert_eq(s.hand.size(), 0)


func test_draw_cards_roba_todas_disponibles_si_pide_mas() -> void:
	# draw(2) + discard(2), pide 5 → roba 4 (2 directos + reshuffle + 2 más, luego ambos vacíos)
	var s := CombatState.new()
	s.draw_pile.assign(_make_deck(2))
	s.discard_pile.assign(_make_deck(2))

	_make_manager(s).draw_cards(5)

	assert_eq(s.hand.size(), 4)
	assert_eq(s.draw_pile.size(), 0)
	assert_eq(s.discard_pile.size(), 0)


# ── discard_hand ──────────────────────────────────────────────────────────────

func test_discard_hand_mueve_todas_las_cartas_al_descarte() -> void:
	var s := CombatState.new()
	s.hand.assign(_make_deck(3))

	_make_manager(s).discard_hand()

	assert_eq(s.discard_pile.size(), 3)


func test_discard_hand_vacia_la_mano() -> void:
	var s := CombatState.new()
	s.hand.assign(_make_deck(3))

	_make_manager(s).discard_hand()

	assert_eq(s.hand.size(), 0)


func test_discard_hand_acumula_sobre_descarte_existente() -> void:
	var s := CombatState.new()
	s.hand.assign(_make_deck(3))
	s.discard_pile.assign(_make_deck(2))

	_make_manager(s).discard_hand()

	assert_eq(s.discard_pile.size(), 5)


# ── reset_turn ────────────────────────────────────────────────────────────────

func test_reset_turn_limpia_las_acciones_del_turno() -> void:
	var s := CombatState.new()
	s.turn_actions.append(CardAction.new())

	_make_manager(s).reset_turn(5)

	assert_eq(s.turn_actions.size(), 0)


func test_reset_turn_pone_bloqueo_en_cero() -> void:
	var s := CombatState.new()
	s.player_block = 8

	_make_manager(s).reset_turn(5)

	assert_eq(s.player_block, 0)


func test_reset_turn_descarta_la_mano() -> void:
	var s := CombatState.new()
	s.hand.assign(_make_deck(3))
	s.draw_pile.assign(_make_deck(10))

	_make_manager(s).reset_turn(5)

	assert_false(s.discard_pile.is_empty())


func test_reset_turn_roba_hand_size_cartas() -> void:
	var s := CombatState.new()
	s.draw_pile.assign(_make_deck(10))

	_make_manager(s).reset_turn(5)

	assert_eq(s.hand.size(), 5)


# ── Cartas dobles ─────────────────────────────────────────────────────────────

func test_todas_las_cartas_tienen_accion_superior_inferior_e_iniciativa() -> void:
	for card: CardData in CardDatabase.cards_by_id.values():
		assert_not_null(card.top, "%s sin acción superior" % card.id)
		assert_not_null(card.bottom, "%s sin acción inferior" % card.id)
		assert_false(card.top.lines.is_empty(), "%s: mitad superior sin líneas" % card.id)
		assert_false(card.bottom.lines.is_empty(), "%s: mitad inferior sin líneas" % card.id)
		assert_gt(card.initiative, 0, "%s sin iniciativa" % card.id)


func test_get_action_devuelve_la_mitad_pedida_y_nombra_sus_lineas() -> void:
	var c := CardData.new()
	c.name = "Golpe"
	c.top = CardAction.new()
	c.bottom = CardAction.new()
	c.bottom.lines.append(CardActionLine.new())
	c.bottom.lines.append(CardActionLine.new())

	assert_eq(c.get_action(true), c.top)
	assert_eq(c.get_action(false), c.bottom)
	for line in c.get_action(false).lines:
		assert_eq(line.name, "Golpe")


func test_enabled_lines_omite_las_lineas_desactivadas_y_mantiene_el_orden() -> void:
	var half := CardAction.new()
	var a := CardActionLine.new(); a.card_type = "move"
	var b := CardActionLine.new(); b.card_type = "melee_attack"; b.enabled = false
	var c := CardActionLine.new(); c.card_type = "range_attack"
	half.lines.assign([a, b, c])

	assert_eq(half.enabled_lines(), [a, c] as Array[CardActionLine])


# ── Comodín "mantener carta" ──────────────────────────────────────────────────

func test_reset_turn_mantiene_las_cartas_indicadas_en_la_mano() -> void:
	var s := CombatState.new()
	var hand := _make_deck(4)
	s.hand.assign(hand)
	s.draw_pile.assign(_make_deck(10))

	_make_manager(s).reset_turn(4, [2])

	assert_eq(s.hand.size(), 4)
	assert_true(s.hand.has(hand[2]))
	assert_false(s.discard_pile.has(hand[2]))
	assert_eq(s.discard_pile.size(), 3)


func test_reset_turn_sin_mantener_descarta_todo() -> void:
	var s := CombatState.new()
	var hand := _make_deck(3)
	s.hand.assign(hand)
	s.draw_pile.assign(_make_deck(10))

	_make_manager(s).reset_turn(3)

	for c in hand:
		assert_false(s.hand.has(c))


func test_reset_turn_pone_bloqueo_del_enemigo_en_cero() -> void:
	var s := CombatState.new()
	s.enemy_block = 5

	_make_manager(s).reset_turn(5)

	assert_eq(s.enemy_block, 0)
