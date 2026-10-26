extends "res://tests/helpers/combat_test_case.gd"

## Pruebas del mazo, iniciativa y ejecución de cartas del enemigo.

# ── Cartas de monstruo ────────────────────────────────────────────────────────

func test_draw_card_toma_la_iniciativa_de_la_carta() -> void:
	var s := CombatState.new()
	var ai := _make_card_ai(s, _make_monster_deck([_make_monster_card(19, [])]))
	ai.draw_card()
	assert_eq(ai.initiative, 19)


func test_draw_card_no_repite_mientras_queden_3_por_usar() -> void:
	# 6 cartas: en las primeras 4 rondas siempre quedan 3 o más sin usar
	var s := CombatState.new()
	var cards := []
	for i in 6:
		cards.append(_make_monster_card(10 + i, []))
	var ai := _make_card_ai(s, _make_monster_deck(cards))
	var seen := []
	for i in 4:
		var c := ai.draw_card()
		assert_false(seen.has(c))
		seen.append(c)


func test_draw_card_mira_3_opciones_y_la_elegida_esta_entre_ellas() -> void:
	var s := CombatState.new()
	var cards := []
	for i in 6:
		cards.append(_make_monster_card(10 + i, []))
	var ai := _make_card_ai(s, _make_monster_deck(cards))
	var chosen := ai.draw_card()
	assert_eq(ai.round_options.size(), CombatEnemyAI.ROUND_OPTIONS)
	assert_true(ai.round_options.has(chosen))


func test_las_opciones_son_3_cartas_distintas() -> void:
	var s := CombatState.new()
	var cards := []
	for i in 6:
		cards.append(_make_monster_card(10 + i, []))
	var ai := _make_card_ai(s, _make_monster_deck(cards))
	for _round in 10:
		ai.draw_card()
		var unique := {}
		for c in ai.round_options:
			unique[c] = true
		assert_eq(unique.size(), 3)


func test_siempre_hay_3_opciones_aunque_queden_menos_en_el_mazo() -> void:
	var s := CombatState.new()
	var cards := [_make_monster_card(10, []), _make_monster_card(20, []), _make_monster_card(30, []), _make_monster_card(40, [])]
	var ai := _make_card_ai(s, _make_monster_deck(cards))
	var sizes := []
	for i in 6:
		ai.draw_card()
		sizes.append(ai.round_options.size())
	assert_eq(sizes, [3, 3, 3, 3, 3, 3])


func test_con_mazo_de_menos_de_3_las_opciones_son_las_que_hay() -> void:
	var s := CombatState.new()
	var cards := [_make_monster_card(10, []), _make_monster_card(20, [])]
	var ai := _make_card_ai(s, _make_monster_deck(cards))
	ai.draw_card()
	assert_eq(ai.round_options.size(), 2)


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
