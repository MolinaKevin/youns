class_name CombatEnemyAI
extends RefCounted

var state
var map_area: Node
var _strategy: AiStrategy
var initiative: int = 50

## Con mazo, cada ronda roba una carta y ejecuta sus acciones en orden.
## Sin mazo usa la estrategia (_strategy) como antes.
var monster_deck: MonsterDeck
var current_card: MonsterCard
var _card_pile: Array[MonsterCard] = []
## Pausa entre las acciones de una carta, para que se lean de a una.
var action_delay := 0.35

var _current_phase: String = ""
var last_known_player_pos: Vector2 = Vector2.ZERO
var _had_los: bool = false

var _deal_damage_to_enemy: Callable
var _deal_damage_to_player: Callable
var _check_combat_end: Callable

signal log_requested(text: String)
signal ui_update_requested()
## Se emite al empezar cada acción de current_card (índice en card.actions).
signal card_action_started(index: int)

func setup(p_state, p_map_area: Node, strategy: AiStrategy, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	_strategy = strategy
	_deal_damage_to_enemy = p_damage_enemy
	_deal_damage_to_player = p_damage_player
	_check_combat_end = p_check_end
	if _strategy != null and _strategy.initial_phase != "":
		_current_phase = _strategy.initial_phase

# ── Mazo de cartas ────────────────────────────────────────────────────────────

func set_monster_deck(deck: MonsterDeck) -> void:
	monster_deck = deck
	_card_pile.clear()

## Roba la carta de la ronda y toma su iniciativa. Las cartas no se repiten
## hasta que se usaron todas; ahí se vuelve a mezclar el mazo.
func draw_card() -> MonsterCard:
	if monster_deck == null or monster_deck.cards.is_empty():
		current_card = null
		return null
	if _card_pile.is_empty():
		_card_pile.assign(monster_deck.cards)
		_card_pile.shuffle()
	current_card = _card_pile.pop_back()
	initiative = current_card.initiative
	return current_card

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

# ── Transitions ───────────────────────────────────────────────────────────────

func evaluate_transitions() -> void:
	if _strategy == null:
		return
	for trans in _strategy.transitions:
		if trans.from_phase != _current_phase:
			continue
		if _conditions_met_list(trans.conditions):
			_current_phase = trans.target_phase
			return

# ── Evaluation ────────────────────────────────────────────────────────────────

func pick_action() -> AiAction:
	if _strategy == null:
		return null
	if _current_phase != "":
		var phase := _get_phase(_current_phase)
		if phase == null:
			return null
		return _pick_best_from(phase.actions)
	return _pick_best_from(_strategy.actions)

func _get_phase(phase_name: String) -> AiPhase:
	for phase in _strategy.phases:
		if phase.phase_name == phase_name:
			return phase
	return null

func _pick_best_from(actions: Array) -> AiAction:
	var best: AiAction = null
	var best_score: float = -INF
	for action in actions:
		if not _conditions_met(action):
			continue
		var score := _compute_score(action)
		if score > best_score:
			best_score = score
			best = action
	return best

func _conditions_met(action: AiAction) -> bool:
	return _conditions_met_list(action.conditions)

func _conditions_met_list(conditions: Array) -> bool:
	for cond in conditions:
		if not _eval_condition(cond):
			return false
	return true

func _eval_condition(cond: AiCondition) -> bool:
	var dist: float = map_area.movement_distance(map_area.enemy_pos, map_area.player_pos)
	match cond.type:
		"always":
			return true
		"player_adjacent":
			return dist <= cond.check_range
		"player_in_range":
			return dist <= cond.check_range \
				and map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
		"player_out_of_range":
			return dist > cond.check_range \
				or not map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
		"player_far":
			return dist > 15.0
		"self_hp_low":
			return float(state.enemy_hp) / float(state.enemy_max_hp) < 0.3
		"self_hp_critical":
			return float(state.enemy_hp) / float(state.enemy_max_hp) < 0.15
		"has_los":
			return map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
		"player_hidden":
			return _had_los \
				and not map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
	push_warning("CombatEnemyAI: condición desconocida '%s'" % cond.type)
	return false

func _compute_score(action: AiAction) -> float:
	var score := action.base_score
	if float(state.enemy_hp) / float(state.enemy_max_hp) < 0.3:
		score *= action.score_multiplier_low_hp
	return score

# ── Execution ─────────────────────────────────────────────────────────────────

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
	var fx: Dictionary = map_area.get_puddle_effects_along(from_pos, map_area.enemy_pos)
	var zone_dmg: Dictionary = map_area.get_puddle_damage_along(from_pos, map_area.enemy_pos)
	if fx.get("wet", false) and state.enemy_wet_turns == 0:
		state.enemy_wet_turns = state.status_turns(3, false)
		log_requested.emit("El enemigo pisó agua. ¡Está mojado!")
	if fx.get("fire", false) and state.enemy_burning_turns == 0:
		state.enemy_burning_turns = state.status_turns(3, false)
		state.enemy_burn_damage = zone_dmg.get("fire", CombatState.BURN_DAMAGE)
		log_requested.emit("El enemigo entró en el fuego. ¡Está en llamas!")
	if fx.get("grease", false) and state.enemy_greasy_turns == 0:
		state.enemy_greasy_turns = state.status_turns(3, false)
		log_requested.emit("El enemigo pisó grasa. ¡Movimiento reducido!")
	if fx.get("vine", false) and state.enemy_entangled_turns == 0:
		state.enemy_entangled_turns = state.status_turns(2, false)
		log_requested.emit("¡El enemigo quedó enredado por %d turnos!" % state.enemy_entangled_turns)
	if fx.get("blood", false) and state.enemy_bleeding_turns == 0:
		state.enemy_bleeding_turns = state.status_turns(4, false)
		state.enemy_bleed_damage = zone_dmg.get("blood", CombatState.BLEED_DAMAGE)
		log_requested.emit("El enemigo pisó sangre. ¡Está sangrando!")
	if fx.get("poison", false) and state.enemy_poison_stacks == 0:
		state.enemy_poison_stacks = state.status_turns(3, false)
		state.enemy_poison_damage = zone_dmg.get("poison", CombatState.POISON_DAMAGE_PER_STACK)
		log_requested.emit("El enemigo pisó veneno. ¡Está envenenado!")
	if fx.get("sand", false) and state.enemy_blinded_turns == 0:
		state.enemy_blinded_turns = state.status_turns(2, false)
		log_requested.emit("¡El enemigo fue cegado por %d turnos!" % state.enemy_blinded_turns)
	if fx.get("ice", false) and state.enemy_frozen_turns == 0:
		state.enemy_frozen_turns = state.status_turns(2, false)
		log_requested.emit("¡El enemigo pisó hielo y quedó congelado por %d turnos!" % state.enemy_frozen_turns)
	if fx.get("bloody_ice", false):
		if state.enemy_frozen_turns == 0:
			state.enemy_frozen_turns = state.status_turns(2, false)
		if state.enemy_bleeding_turns == 0:
			state.enemy_bleeding_turns = state.status_turns(3, false)
			state.enemy_bleed_damage = zone_dmg.get("bloody_ice", CombatState.BLEED_DAMAGE)
		log_requested.emit("¡El enemigo pisó hielo sangriento! Congelado y sangrando.")
	if fx.get("dark_smoke", false) and state.enemy_blinded_turns == 0:
		state.enemy_blinded_turns = state.status_turns(3, false)
		log_requested.emit("¡El enemigo quedó cegado por el humo oscuro!")

## En unidades de mundo (1 unidad = 12,5 casillas), como el rango que recibe _move_enemy.
func _enemy_move_penalty() -> int:
	return (1 if state.enemy_wet_turns > 0 else 0) + (2 if state.enemy_greasy_turns > 0 else 0)

func _execute_action(action: AiAction) -> void:
	match action.action_type:
		"melee_attack":
			if state.player_in_tree:
				log_requested.emit("El enemigo no te alcanza: estás arriba del árbol.")
				return
			log_requested.emit("Enemy strikes for %d!" % action.damage)
			await _deal_damage_to_player.call(action.damage, false, action.damage_type)
			await _try_player_counter()
		"range_attack":
			if state.enemy_blinded_turns > 0 and map_area.movement_distance(map_area.enemy_pos, map_area.player_pos) > 2.0:
				log_requested.emit("El enemigo está cegado y no puede atacar a distancia.")
				return
			if state.player_in_tree:
				log_requested.emit("El enemigo no te alcanza: estás arriba del árbol.")
				return
			log_requested.emit("Enemy shoots for %d!" % action.damage)
			await _deal_damage_to_player.call(action.damage, false, action.damage_type)
		"move_toward":
			await _move_enemy(map_area.player_pos, action.move_range, "Enemy moves closer.")
		"move_away":
			await _move_enemy(_retreat_target(action.move_range), action.move_range, "Enemy retreats!")
		"move_to_last_known":
			await _move_enemy(last_known_player_pos, action.move_range, "Enemy searches last known position.")
		"block":
			state.enemy_block += action.block_amount
			log_requested.emit("Enemy braces! (%d block)" % action.block_amount)
		"ward":
			state.enemy_ward += action.block_amount
			log_requested.emit("El enemigo levanta un escudo mágico (%d)." % action.block_amount)
		_:
			push_warning("CombatEnemyAI: tipo de acción desconocido '%s'" % action.action_type)

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

# ── Cartas de monstruo ────────────────────────────────────────────────────────

func execute_card(card: MonsterCard) -> void:
	log_requested.emit("%s juega «%s»." % [LocalizationState.t("combat.enemy"), card.card_name])
	for i in card.actions.size():
		card_action_started.emit(i)
		await _execute_card_action(card, i)
		if _check_combat_end.call():
			return
		ui_update_requested.emit()
		if action_delay > 0.0:
			await (Engine.get_main_loop() as SceneTree).create_timer(action_delay).timeout
	card_action_started.emit(-1)

func _execute_card_action(card: MonsterCard, index: int) -> void:
	var action: MonsterCardAction = card.actions[index]
	match action.type:
		"move":
			# Si ya está al alcance del próximo ataque de la carta, no se mueve.
			var next_attack := _next_attack(card, index)
			if next_attack != null and _player_in_reach(monster_deck.reach_for(next_attack)):
				log_requested.emit("El enemigo se queda en posición.")
				return
			var amount := monster_deck.move_for(action)
			if amount > 0:
				await _move_enemy(map_area.player_pos, _w(amount), "El enemigo avanza %d." % amount)
		"retreat":
			var amount := monster_deck.move_for(action)
			if amount > 0:
				await _move_enemy(_retreat_target(_w(amount)), _w(amount), "El enemigo retrocede %d." % amount)
		"attack":
			var reach := monster_deck.reach_for(action)
			if state.enemy_blinded_turns > 0:
				reach = mini(reach, MonsterDeck.MELEE_REACH_CELLS)
			if not _player_in_reach(reach):
				log_requested.emit("El ataque del enemigo no alcanza.")
				return
			if state.player_in_tree:
				log_requested.emit("El enemigo no te alcanza: estás arriba del árbol.")
				return
			var dmg := monster_deck.attack_for(action)
			log_requested.emit("¡El enemigo ataca por %d!" % dmg)
			await _deal_damage_to_player.call(dmg, false, action.damage_type)
			await _try_player_counter()
		"block":
			state.enemy_block += action.value
			log_requested.emit("El enemigo se cubre (%d de bloqueo)." % action.value)
		"ward":
			state.enemy_ward += action.value
			log_requested.emit("El enemigo levanta un escudo mágico (%d)." % action.value)
		"heal":
			var before: int = state.enemy_hp
			state.enemy_hp = mini(state.enemy_max_hp, state.enemy_hp + action.value)
			if map_area.has_method("set_enemy_hp"):
				map_area.set_enemy_hp(state.enemy_hp)
			log_requested.emit("El enemigo se cura %d." % (state.enemy_hp - before))
		_:
			push_warning("CombatEnemyAI: acción de carta desconocida '%s'" % action.type)

func _next_attack(card: MonsterCard, from_index: int) -> MonsterCardAction:
	for i in range(from_index + 1, card.actions.size()):
		if card.actions[i].type == "attack":
			return card.actions[i]
	return null

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

static func _w(cells: int) -> float:
	return float(cells) * CombatGrid.CELL
