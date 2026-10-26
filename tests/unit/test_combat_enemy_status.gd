extends "res://tests/helpers/combat_test_case.gd"

## Pruebas de estados, resistencias y reacciones del enemigo durante el combate.

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
	assert_eq(_make_ai_full(s).move_penalty(), 3)


func test_enemy_move_penalty_cero_sin_estados() -> void:
	var s := CombatState.new()
	assert_eq(_make_ai_full(s).move_penalty(), 0)


# ── Estados — inmovilización (enredado / congelado) del enemigo ─────────────

func test_enemy_enredado_no_puede_moverse() -> void:
	var s := CombatState.new()
	s.enemy_entangled_turns = 2
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s).execute_action(action)
	assert_eq(_map.move_enemy_toward_calls, 0)


func test_enemy_congelado_no_puede_moverse() -> void:
	var s := CombatState.new()
	s.enemy_frozen_turns = 2
	var action := _make_action("move_away", 50.0, [_make_condition("always")])
	await _make_ai_full(s).execute_action(action)
	assert_eq(_map.move_enemy_toward_calls, 0)


func test_enemy_sin_inmovilizacion_puede_moverse() -> void:
	var s := CombatState.new()
	var action := _make_action("move_toward", 50.0, [_make_condition("always")])
	await _make_ai_full(s).execute_action(action)
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
	await _make_ai_full(s).execute_action(action)
	assert_eq(s.player_hp, 20)


func test_enemy_cegado_permite_ataque_a_distancia_menor_igual_a_2() -> void:
	var s := CombatState.new()
	s.enemy_blinded_turns = 1
	s.player_hp = 20
	_map.player_pos = Vector2.ZERO
	_map.enemy_pos  = Vector2(2.0, 0.0)
	var action := _make_action("range_attack", 50.0, [_make_condition("always")])
	action.damage = 10
	await _make_ai_full(s).execute_action(action)
	assert_eq(s.player_hp, 10)

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
	ai.apply_zone_effects(Vector2.ZERO)
	assert_eq(s.enemy_burning_turns, 2)
