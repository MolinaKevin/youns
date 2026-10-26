extends GutTest

## Reglas puras de CombatState y costo de MP; no necesitan mapa ni actores 3D.


# ── CombatState — valores iniciales ──────────────────────────────────────────

func test_estado_inicial_pilas_vacias() -> void:
	var s := CombatState.new()
	assert_true(s.hand.is_empty())
	assert_true(s.draw_pile.is_empty())
	assert_true(s.discard_pile.is_empty())


func test_resumen_de_estados_para_mostrar_sobre_los_personajes() -> void:
	var previous_language := LocalizationState.current_language
	LocalizationState.set_language("es")
	var s := CombatState.new()
	assert_eq(s.status_summary(true), "")
	s.player_burning_turns = 2
	s.player_block = 30
	s.player_in_tree = true
	assert_eq(s.status_summary(true), "Fuego 2 · Bloqueo 30 · En el árbol")
	s.enemy_wet_turns = 3
	s.enemy_ward = 20
	assert_eq(s.status_summary(false), "Mojado 3 · Escudo mágico 20")
	LocalizationState.set_language(previous_language)


func test_resumen_de_estados_se_localiza_al_ingles() -> void:
	var previous_language := LocalizationState.current_language
	LocalizationState.set_language("en")
	var s := CombatState.new()
	s.player_burning_turns = 2
	s.player_block = 30
	s.player_in_tree = true
	assert_eq(s.status_summary(true), "Burning 2 · Block 30 · In tree")
	LocalizationState.set_language(previous_language)


func test_estado_inicial_sin_bloqueo() -> void:
	var s := CombatState.new()
	assert_eq(s.player_block, 0)
	assert_eq(s.enemy_block, 0)


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


# ── Daño físico y mágico ─────────────────────────────────────────────────────

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
	assert_eq(s.damage_enemy(8), 8)
	assert_eq(s.enemy_hp, hp_inicial - 8)


func test_danio_totalmente_absorbido_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.enemy_block = 10
	var hp_inicial := s.enemy_hp
	s.damage_enemy(6)
	assert_eq(s.enemy_hp, hp_inicial)


func test_danio_totalmente_absorbido_reduce_bloqueo() -> void:
	var s := CombatState.new()
	s.enemy_block = 10
	s.damage_enemy(6)
	assert_eq(s.enemy_block, 4)


func test_danio_parcial_reduce_hp_y_elimina_bloqueo() -> void:
	var s := CombatState.new()
	s.enemy_block = 3
	var hp_inicial := s.enemy_hp
	s.damage_enemy(8)
	assert_eq(s.enemy_hp, hp_inicial - 5)
	assert_eq(s.enemy_block, 0)


func test_danio_exactamente_igual_al_bloqueo_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.enemy_block = 5
	var hp_inicial := s.enemy_hp
	s.damage_enemy(5)
	assert_eq(s.enemy_hp, hp_inicial)
	assert_eq(s.enemy_block, 0)


func test_danio_jugador_sin_bloqueo_reduce_hp_completo() -> void:
	var s := CombatState.new()
	var hp_inicial := s.player_hp
	s.damage_player(8)
	assert_eq(s.player_hp, hp_inicial - 8)


func test_danio_jugador_totalmente_absorbido_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.player_block = 10
	var hp_inicial := s.player_hp
	s.damage_player(6)
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 4)


func test_danio_jugador_parcial_reduce_hp_y_elimina_bloqueo() -> void:
	var s := CombatState.new()
	s.player_block = 3
	var hp_inicial := s.player_hp
	s.damage_player(8)
	assert_eq(s.player_hp, hp_inicial - 5)
	assert_eq(s.player_block, 0)


func test_danio_jugador_exactamente_igual_al_bloqueo_no_reduce_hp() -> void:
	var s := CombatState.new()
	s.player_block = 5
	var hp_inicial := s.player_hp
	s.damage_player(5)
	assert_eq(s.player_hp, hp_inicial)
	assert_eq(s.player_block, 0)
