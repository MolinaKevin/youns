class_name CombatEnemyAI
extends RefCounted

var state: CombatState
var map_area: CombatMapArea
var zone_effects := CombatZoneEffectResolver.new()
var initiative: int = 50

## Con mazo, cada ronda roba una carta y ejecuta sus acciones en orden (ver
## CombatEnemyCardAi). Sin mazo usa la estrategia de fases/condiciones (ver
## CombatEnemyStrategyAi) como antes.
var monster_deck: MonsterDeck
var current_card: MonsterCard
## Pausa entre las acciones de una carta, para que se lean de a una.
var action_delay := 0.35
## Las cartas entre las que eligió esta ronda (incluye current_card). Las que no
## eligió vuelven al mazo; en la revelación se muestran dadas vuelta.
var round_options: Array[MonsterCard] = []
const ROUND_OPTIONS := CombatEnemyCardAi.ROUND_OPTIONS

var last_known_player_pos: Vector2 = Vector2.ZERO
var _had_los: bool = false

var _card_ai: CombatEnemyCardAi
var _strategy_ai: CombatEnemyStrategyAi

var deal_damage_to_enemy: Callable
var deal_damage_to_player: Callable
var check_combat_end: Callable

signal log_requested(text: String)
signal ui_update_requested()
## Se emite al empezar cada acción de current_card (índice en card.actions).
signal card_action_started(index: int)

func emit_log(key: String, args: Array = []) -> void:
	CombatLog.emit_requested(log_requested, key, args)

func _init() -> void:
	_card_ai = CombatEnemyCardAi.new(self)
	_strategy_ai = CombatEnemyStrategyAi.new(self)

func setup(p_state: CombatState, p_map_area: CombatMapArea, strategy: AiStrategy, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	_strategy_ai.configure(strategy)
	deal_damage_to_enemy = p_damage_enemy
	deal_damage_to_player = p_damage_player
	check_combat_end = p_check_end

# ── Mazo de cartas ────────────────────────────────────────────────────────────

func set_monster_deck(deck: MonsterDeck) -> void:
	monster_deck = deck
	_card_ai.clear_pile()

func draw_card() -> MonsterCard:
	return _card_ai.draw_card()

func execute_card(card: MonsterCard) -> void:
	await _card_ai.execute_card(card)

# ── Turn ──────────────────────────────────────────────────────────────────────

func take_turn() -> void:
	if state.enemy_burning_turns > 0:
		emit_log("combat.log.enemy.burning_damage", [state.enemy_burn_damage])
		await deal_damage_to_enemy.call(state.enemy_burn_damage, true, CombatState.BURN_DAMAGE_TYPE)
		if check_combat_end.call(): return
		state.enemy_burning_turns -= 1
		if state.enemy_burning_turns == 0:
			emit_log("combat.log.enemy.burning_expired")

	if state.enemy_bleeding_turns > 0:
		emit_log("combat.log.enemy.bleeding_damage", [state.enemy_bleed_damage])
		await deal_damage_to_enemy.call(state.enemy_bleed_damage, true, CombatState.BLEED_DAMAGE_TYPE)
		if check_combat_end.call(): return
		state.enemy_bleeding_turns -= 1
		if state.enemy_bleeding_turns == 0:
			emit_log("combat.log.enemy.bleeding_expired")

	if state.enemy_poison_stacks > 0:
		var pdmg: int = state.enemy_poison_stacks * state.enemy_poison_damage
		emit_log("combat.log.enemy.poison_damage", [pdmg])
		await deal_damage_to_enemy.call(pdmg, true, CombatState.POISON_DAMAGE_TYPE)
		if check_combat_end.call(): return
		state.enemy_poison_stacks -= 1
		if state.enemy_poison_stacks == 0:
			emit_log("combat.log.enemy.poison_expired")


	if state.enemy_wet_turns > 0:
		state.enemy_wet_turns -= 1
		if state.enemy_wet_turns == 0:
			emit_log("combat.log.enemy.wet_expired")

	if state.enemy_greasy_turns > 0:
		state.enemy_greasy_turns -= 1
		if state.enemy_greasy_turns == 0:
			emit_log("combat.log.enemy.greasy_expired")

	if state.enemy_entangled_turns > 0:
		state.enemy_entangled_turns -= 1
		if state.enemy_entangled_turns == 0:
			emit_log("combat.log.enemy.entangled_expired")

	if state.enemy_blinded_turns > 0:
		state.enemy_blinded_turns -= 1
		if state.enemy_blinded_turns == 0:
			emit_log("combat.log.enemy.blinded_expired")

	if state.enemy_frozen_turns > 0:
		state.enemy_frozen_turns -= 1
		if state.enemy_frozen_turns == 0:
			emit_log("combat.log.enemy.frozen_expired")

	var trap_dmg: int = map_area.interactions.trigger_traps(map_area.enemy_pos)
	if trap_dmg > 0:
		await deal_damage_to_enemy.call(trap_dmg)
		emit_log("combat.log.enemy.trap_triggered", [trap_dmg])
		if check_combat_end.call():
			return

	update_tracking()
	if current_card != null:
		await execute_card(current_card)
		ui_update_requested.emit()
		return
	evaluate_transitions()
	var action: AiAction = pick_action()
	if action:
		await execute_action(action)
	else:
		var center := Vector2(map_area.WORLD_W * 0.5, map_area.WORLD_H * 0.5)
		if map_area.enemy_pos.distance_to(center) > 0.5:
			map_area.movement.move_enemy_toward(center, 3)
			emit_log("combat.log.enemy.wanders_to_center")

	ui_update_requested.emit()

# ── Tracking ──────────────────────────────────────────────────────────────────

func update_tracking() -> void:
	if map_area.queries.has_line_of_sight(map_area.enemy_pos, map_area.player_pos):
		last_known_player_pos = map_area.player_pos
		_had_los = true

# ── Strategy (fases/condiciones; ver CombatEnemyStrategyAi) ───────────────────

func evaluate_transitions() -> void:
	_strategy_ai.evaluate_transitions()

func pick_action() -> AiAction:
	return _strategy_ai.pick_action()

## Ejecuta una acción de estrategia. La usan el turno normal y las pruebas de
## reglas de estado, sin depender de detalles del selector de fases.
func execute_action(action: AiAction) -> void:
	await _strategy_ai.execute_action(action)

func score_action(action: AiAction) -> float:
	return _strategy_ai.score_action(action)

# ── Execution (infraestructura compartida por las dos IA) ────────────────────

func _check_overwatch_trigger(from_pos: Vector2) -> bool:
	if not state.player_overwatch_active:
		return false
	if map_area.interactions.segment_is_in_overwatch_cone(
			from_pos, map_area.enemy_pos,
			state.player_overwatch_origin, state.player_overwatch_dir,
			state.player_overwatch_range, state.player_overwatch_half_angle):
		state.player_overwatch_active = false
		map_area.interactions.clear_overwatch_zone()
		return true
	return false

## Aplica los efectos de terreno al recorrido más reciente del enemigo.
func apply_zone_effects(from_pos: Vector2) -> void:
	var contact_margin: float = map_area.queries.enemy_area_contact_radius()
	var fx: Dictionary = map_area.interactions.puddle_effects_along(from_pos, map_area.enemy_pos, contact_margin)
	var zone_dmg: Dictionary = map_area.interactions.puddle_damage_along(from_pos, map_area.enemy_pos, contact_margin)
	for event in zone_effects.apply_path_effects(state, fx, zone_dmg, false):
		zone_effects.log_zone_effect(event, "combat.log.enemy.zone", CombatZoneEffectResolver.ENEMY_LOG_TURNS, emit_log)

## En unidades de mundo (1 unidad = 12,5 casillas), como el rango que recibe _move_enemy.
func move_penalty() -> int:
	return (1 if state.enemy_wet_turns > 0 else 0) + (2 if state.enemy_greasy_turns > 0 else 0)

## Mueve al enemigo hacia target aplicando estados (enredado, congelado,
## mojado, engrasado), efectos de zona y la vigilancia del jugador.
func _move_enemy(target: Vector2, move_range: float, log_key: String, log_args: Array = []) -> void:
	if state.enemy_entangled_turns > 0 or state.enemy_frozen_turns > 0:
		emit_log("combat.log.enemy.cannot_move")
		return
	var from_pos: Vector2 = map_area.enemy_pos
	var eff_range := maxf(CombatGrid.CELL, move_range - float(move_penalty()))
	map_area.movement.move_enemy_toward(target, eff_range)
	apply_zone_effects(from_pos)
	var ow_dmg: int = state.player_overwatch_damage
	var ow_type: String = state.player_overwatch_damage_type
	if _check_overwatch_trigger(from_pos):
		emit_log("combat.log.enemy.overwatch_triggered")
		await deal_damage_to_enemy.call(ow_dmg, false, ow_type)
	else:
		emit_log(log_key, log_args)

func _retreat_target(move_range: float) -> Vector2:
	var away_dir: Vector2 = (map_area.enemy_pos - map_area.player_pos).normalized()
	var target: Vector2 = map_area.enemy_pos + away_dir * move_range
	target.x = clampf(target.x, 0.0, map_area.WORLD_W)
	target.y = clampf(target.y, 0.0, map_area.WORLD_H)
	return target

## reach en casillas, medido entre los bordes de las huellas (como el jugador).
## Si el jugador tiene contraataque y el enemigo le pegó cuerpo a cuerpo, le
## devuelve el golpe (daño físico).
func _try_player_counter() -> void:
	if state.player_counter_damage <= 0 or state.player_hp <= 0:
		return
	if not _player_in_reach(MonsterDeck.MELEE_REACH_CELLS):
		return
	emit_log("combat.log.player.counterattack", [state.player_counter_damage])
	await deal_damage_to_enemy.call(state.player_counter_damage, false, CombatState.FISICO)

func _player_in_reach(reach: int) -> bool:
	return map_area.queries.actors_gap() <= w(reach) + CombatGrid.CELL * 0.5 \
		and map_area.queries.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)

func w(cells: int) -> float:
	return CombatGrid.world_for(cells)
