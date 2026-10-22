class_name CombatEnemyAI
extends RefCounted

var state
var map_area: Node
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

var _deal_damage_to_enemy: Callable
var _deal_damage_to_player: Callable
var _check_combat_end: Callable

signal log_requested(text: String)
signal ui_update_requested()
## Se emite al empezar cada acción de current_card (índice en card.actions).
signal card_action_started(index: int)

func _init() -> void:
	_card_ai = CombatEnemyCardAi.new(self)
	_strategy_ai = CombatEnemyStrategyAi.new(self)

func setup(p_state, p_map_area: Node, strategy: AiStrategy, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	_strategy_ai.configure(strategy)
	_deal_damage_to_enemy = p_damage_enemy
	_deal_damage_to_player = p_damage_player
	_check_combat_end = p_check_end

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
		log_requested.emit("El enemigo está en llamas — %d de daño." % state.enemy_burn_damage)
		await _deal_damage_to_enemy.call(state.enemy_burn_damage, true, CombatState.BURN_DAMAGE_TYPE)
		if _check_combat_end.call(): return
		state.enemy_burning_turns -= 1
		if state.enemy_burning_turns == 0:
			log_requested.emit("El enemigo ya no está en llamas.")

	if state.enemy_bleeding_turns > 0:
		log_requested.emit("El enemigo está sangrando — %d de daño." % state.enemy_bleed_damage)
		await _deal_damage_to_enemy.call(state.enemy_bleed_damage, true, CombatState.BLEED_DAMAGE_TYPE)
		if _check_combat_end.call(): return
		state.enemy_bleeding_turns -= 1
		if state.enemy_bleeding_turns == 0:
			log_requested.emit("El enemigo dejó de sangrar.")

	if state.enemy_poison_stacks > 0:
		var pdmg: int = state.enemy_poison_stacks * state.enemy_poison_damage
		log_requested.emit("El enemigo está envenenado — %d de daño." % pdmg)
		await _deal_damage_to_enemy.call(pdmg, true, CombatState.POISON_DAMAGE_TYPE)
		if _check_combat_end.call(): return
		state.enemy_poison_stacks -= 1
		if state.enemy_poison_stacks == 0:
			log_requested.emit("El veneno del enemigo se disipó.")


	if state.enemy_wet_turns > 0:
		state.enemy_wet_turns -= 1
		if state.enemy_wet_turns == 0:
			log_requested.emit("El enemigo ya no está mojado.")

	if state.enemy_greasy_turns > 0:
		state.enemy_greasy_turns -= 1
		if state.enemy_greasy_turns == 0:
			log_requested.emit("El enemigo ya no está engrasado.")

	if state.enemy_entangled_turns > 0:
		state.enemy_entangled_turns -= 1
		if state.enemy_entangled_turns == 0:
			log_requested.emit("El enemigo ya no está enredado.")

	if state.enemy_blinded_turns > 0:
		state.enemy_blinded_turns -= 1
		if state.enemy_blinded_turns == 0:
			log_requested.emit("El enemigo ya no está cegado.")

	if state.enemy_frozen_turns > 0:
		state.enemy_frozen_turns -= 1
		if state.enemy_frozen_turns == 0:
			log_requested.emit("El enemigo ya no está congelado.")

	var trap_dmg: int = map_area.check_and_trigger_traps(map_area.enemy_pos)
	if trap_dmg > 0:
		await _deal_damage_to_enemy.call(trap_dmg)
		log_requested.emit("Enemy triggered a trap! %d damage." % trap_dmg)
		if _check_combat_end.call():
			return

	update_tracking()
	if current_card != null:
		await execute_card(current_card)
		ui_update_requested.emit()
		return
	evaluate_transitions()
	var action: AiAction = pick_action()
	if action:
		await _execute_action(action)
	else:
		var center := Vector2(map_area.WORLD_W * 0.5, map_area.WORLD_H * 0.5)
		if map_area.enemy_pos.distance_to(center) > 0.5:
			map_area.move_enemy_toward(center, 3)
			log_requested.emit("El enemigo deambula hacia el centro.")

	ui_update_requested.emit()

# ── Tracking ──────────────────────────────────────────────────────────────────

func update_tracking() -> void:
	if map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos):
		last_known_player_pos = map_area.player_pos
		_had_los = true

# ── Strategy (fases/condiciones; ver CombatEnemyStrategyAi) ───────────────────

func evaluate_transitions() -> void:
	_strategy_ai.evaluate_transitions()

func pick_action() -> AiAction:
	return _strategy_ai.pick_action()

func _execute_action(action: AiAction) -> void:
	await _strategy_ai.execute_action(action)

func _compute_score(action: AiAction) -> float:
	return _strategy_ai._compute_score(action)

# ── Execution (infraestructura compartida por las dos IA) ────────────────────

func _check_overwatch_trigger(from_pos: Vector2) -> bool:
	if not state.player_overwatch_active:
		return false
	if map_area.is_segment_in_overwatch_cone(
			from_pos, map_area.enemy_pos,
			state.player_overwatch_origin, state.player_overwatch_dir,
			state.player_overwatch_range, state.player_overwatch_half_angle):
		state.player_overwatch_active = false
		map_area.clear_overwatch_zone()
		return true
	return false

func _apply_enemy_zone_effects(from_pos: Vector2) -> void:
	var contact_margin: float = map_area.enemy_area_contact_radius()
	var fx: Dictionary = map_area.get_puddle_effects_along(from_pos, map_area.enemy_pos, contact_margin)
	var zone_dmg: Dictionary = map_area.get_puddle_damage_along(from_pos, map_area.enemy_pos, contact_margin)
	for event in zone_effects.apply_path_effects(state, fx, zone_dmg, false):
		_log_enemy_zone_effect(event)

func _log_enemy_zone_effect(event: Dictionary) -> void:
	match event["effect"]:
		"wet": log_requested.emit("El enemigo pisó agua. ¡Está mojado!")
		"fire": log_requested.emit("El enemigo entró en el fuego. ¡Está en llamas!")
		"grease": log_requested.emit("El enemigo pisó grasa. ¡Movimiento reducido!")
		"vine": log_requested.emit("¡El enemigo quedó enredado por %d turnos!" % event["turns"])
		"blood": log_requested.emit("El enemigo pisó sangre. ¡Está sangrando!")
		"poison": log_requested.emit("El enemigo pisó veneno. ¡Está envenenado!")
		"sand": log_requested.emit("¡El enemigo fue cegado por %d turnos!" % event["turns"])
		"ice": log_requested.emit("¡El enemigo pisó hielo y quedó congelado por %d turnos!" % event["turns"])
		"bloody_ice": log_requested.emit("¡El enemigo pisó hielo sangriento! Congelado y sangrando.")
		"dark_smoke": log_requested.emit("¡El enemigo quedó cegado por el humo oscuro!")

## En unidades de mundo (1 unidad = 12,5 casillas), como el rango que recibe _move_enemy.
func _enemy_move_penalty() -> int:
	return (1 if state.enemy_wet_turns > 0 else 0) + (2 if state.enemy_greasy_turns > 0 else 0)

## Mueve al enemigo hacia target aplicando estados (enredado, congelado,
## mojado, engrasado), efectos de zona y la vigilancia del jugador.
func _move_enemy(target: Vector2, move_range: float, log_text: String) -> void:
	if state.enemy_entangled_turns > 0 or state.enemy_frozen_turns > 0:
		log_requested.emit("El enemigo no puede moverse.")
		return
	var from_pos: Vector2 = map_area.enemy_pos
	var eff_range := maxf(CombatGrid.CELL, move_range - float(_enemy_move_penalty()))
	map_area.move_enemy_toward(target, eff_range)
	_apply_enemy_zone_effects(from_pos)
	var ow_dmg: int = state.player_overwatch_damage
	var ow_type: String = state.player_overwatch_damage_type
	if _check_overwatch_trigger(from_pos):
		log_requested.emit("¡Emboscada! El enemigo entró en la zona de vigilancia.")
		await _deal_damage_to_enemy.call(ow_dmg, false, ow_type)
	else:
		log_requested.emit(log_text)

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
	log_requested.emit("¡Contraataque! Le devolvés %d de daño." % state.player_counter_damage)
	await _deal_damage_to_enemy.call(state.player_counter_damage, false, CombatState.FISICO)

func _player_in_reach(reach: int) -> bool:
	return map_area.actors_gap() <= _w(reach) + CombatGrid.CELL * 0.5 \
		and map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)

func _w(cells: int) -> float:
	return float(cells) * CombatGrid.CELL
