extends GutTest

# Tests para CombatDeckManager: draw, discard y reset de turno.
# CombatDeckManager opera sobre un CombatState y no tiene lógica de UI.


func _make_card(id: String) -> CardData:
	var c := CardData.new()
	c.id = id
	c.name = id
	c.card_type = "block"
	c.cost = 1
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

func test_reset_turn_restaura_energia_al_maximo() -> void:
	var s := CombatState.new()
	s.player_energy = 0

	_make_manager(s).reset_turn(5)

	assert_eq(s.player_energy, s.max_energy)


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
