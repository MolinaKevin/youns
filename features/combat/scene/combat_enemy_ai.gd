class_name CombatEnemyAI
extends RefCounted

var state
var map_area: Node
var _strategy: AiStrategy

var _current_phase: String = ""
var last_known_player_pos: Vector2 = Vector2.ZERO
var _had_los: bool = false

var _deal_damage_to_enemy: Callable
var _deal_damage_to_player: Callable
var _check_combat_end: Callable

signal log_requested(text: String)
signal ui_update_requested()

func setup(p_state, p_map_area: Node, strategy: AiStrategy, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	_strategy = strategy
	_deal_damage_to_enemy = p_damage_enemy
	_deal_damage_to_player = p_damage_player
	_check_combat_end = p_check_end
	if _strategy != null and _strategy.initial_phase != "":
		_current_phase = _strategy.initial_phase

# ── Turn ──────────────────────────────────────────────────────────────────────

func take_turn() -> void:
	if state.enemy_burning_turns > 0:
		log_requested.emit("El enemigo está en llamas — 3 de daño.")
		await _deal_damage_to_enemy.call(3, true)
		if _check_combat_end.call(): return
		state.enemy_burning_turns -= 1
		if state.enemy_burning_turns == 0:
			log_requested.emit("El enemigo ya no está en llamas.")

	if state.enemy_bleeding_turns > 0:
		log_requested.emit("El enemigo está sangrando — 2 de daño.")
		await _deal_damage_to_enemy.call(2, true)
		if _check_combat_end.call(): return
		state.enemy_bleeding_turns -= 1
		if state.enemy_bleeding_turns == 0:
			log_requested.emit("El enemigo dejó de sangrar.")

	if state.enemy_poison_stacks > 0:
		var pdmg: int = state.enemy_poison_stacks
		log_requested.emit("El enemigo está envenenado — %d de daño." % pdmg)
		await _deal_damage_to_enemy.call(pdmg, true)
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
	if fx.get("wet", false) and state.enemy_wet_turns == 0:
		state.enemy_wet_turns = 3
		log_requested.emit("El enemigo pisó agua. ¡Está mojado!")
	if fx.get("fire", false) and state.enemy_burning_turns == 0:
		state.enemy_burning_turns = 3
		log_requested.emit("El enemigo entró en el fuego. ¡Está en llamas!")
	if fx.get("grease", false) and state.enemy_greasy_turns == 0:
		state.enemy_greasy_turns = 3
		log_requested.emit("El enemigo pisó grasa. ¡Movimiento reducido!")
	if fx.get("vine", false) and state.enemy_entangled_turns == 0:
		state.enemy_entangled_turns = 2
		log_requested.emit("¡El enemigo quedó enredado por 2 turnos!")
	if fx.get("blood", false) and state.enemy_bleeding_turns == 0:
		state.enemy_bleeding_turns = 4
		log_requested.emit("El enemigo pisó sangre. ¡Está sangrando!")
	if fx.get("poison", false) and state.enemy_poison_stacks == 0:
		state.enemy_poison_stacks = 3
		log_requested.emit("El enemigo pisó veneno. ¡Está envenenado!")
	if fx.get("sand", false) and state.enemy_blinded_turns == 0:
		state.enemy_blinded_turns = 2
		log_requested.emit("¡El enemigo fue cegado por 2 turnos!")
	if fx.get("ice", false) and state.enemy_frozen_turns == 0:
		state.enemy_frozen_turns = 2
		log_requested.emit("¡El enemigo pisó hielo y quedó congelado por 2 turnos!")
	if fx.get("bloody_ice", false):
		if state.enemy_frozen_turns == 0:
			state.enemy_frozen_turns = 2
		if state.enemy_bleeding_turns == 0:
			state.enemy_bleeding_turns = 3
		log_requested.emit("¡El enemigo pisó hielo sangriento! Congelado y sangrando.")
	if fx.get("dark_smoke", false) and state.enemy_blinded_turns == 0:
		state.enemy_blinded_turns = 3
		log_requested.emit("¡El enemigo quedó cegado por el humo oscuro!")

func _enemy_move_penalty() -> int:
	return (1 if state.enemy_wet_turns > 0 else 0) + (2 if state.enemy_greasy_turns > 0 else 0)

func _execute_action(action: AiAction) -> void:
	match action.action_type:
		"melee_attack":
			log_requested.emit("Enemy strikes for %d!" % action.damage)
			await _deal_damage_to_player.call(action.damage)
		"range_attack":
			if state.enemy_blinded_turns > 0 and map_area.movement_distance(map_area.enemy_pos, map_area.player_pos) > 2.0:
				log_requested.emit("El enemigo está cegado y no puede atacar a distancia.")
				return
			log_requested.emit("Enemy shoots for %d!" % action.damage)
			await _deal_damage_to_player.call(action.damage)
		"move_toward":
			if state.enemy_entangled_turns > 0 or state.enemy_frozen_turns > 0:
				log_requested.emit("El enemigo no puede moverse.")
				return
			var from_pos: Vector2 = map_area.enemy_pos
			var eff_range := maxi(1, action.move_range - _enemy_move_penalty())
			map_area.move_enemy_toward(map_area.player_pos, eff_range)
			_apply_enemy_zone_effects(from_pos)
			var ow_dmg_a: int = state.player_overwatch_damage
			if _check_overwatch_trigger(from_pos):
				log_requested.emit("¡Emboscada! El enemigo entró en la zona de vigilancia.")
				await _deal_damage_to_enemy.call(ow_dmg_a)
				if _check_combat_end.call(): return
			else:
				log_requested.emit("Enemy moves closer.")
		"move_away":
			if state.enemy_entangled_turns > 0 or state.enemy_frozen_turns > 0:
				log_requested.emit("El enemigo no puede moverse.")
				return
			var from_pos: Vector2 = map_area.enemy_pos
			var eff_range := maxi(1, action.move_range - _enemy_move_penalty())
			var away_dir: Vector2 = (map_area.enemy_pos - map_area.player_pos).normalized()
			var target: Vector2   = map_area.enemy_pos + away_dir * eff_range
			target.x = clampf(target.x, 0.0, map_area.WORLD_W)
			target.y = clampf(target.y, 0.0, map_area.WORLD_H)
			map_area.move_enemy_toward(target, eff_range)
			_apply_enemy_zone_effects(from_pos)
			var ow_dmg_b: int = state.player_overwatch_damage
			if _check_overwatch_trigger(from_pos):
				log_requested.emit("¡Emboscada! El enemigo entró en la zona de vigilancia.")
				await _deal_damage_to_enemy.call(ow_dmg_b)
				if _check_combat_end.call(): return
			else:
				log_requested.emit("Enemy retreats!")
		"move_to_last_known":
			if state.enemy_entangled_turns > 0 or state.enemy_frozen_turns > 0:
				log_requested.emit("El enemigo no puede moverse.")
				return
			var from_pos: Vector2 = map_area.enemy_pos
			var eff_range := maxi(1, action.move_range - _enemy_move_penalty())
			map_area.move_enemy_toward(last_known_player_pos, eff_range)
			_apply_enemy_zone_effects(from_pos)
			var ow_dmg_c: int = state.player_overwatch_damage
			if _check_overwatch_trigger(from_pos):
				log_requested.emit("¡Emboscada! El enemigo entró en la zona de vigilancia.")
				await _deal_damage_to_enemy.call(ow_dmg_c)
				if _check_combat_end.call(): return
			else:
				log_requested.emit("Enemy searches last known position.")
		"block":
			state.enemy_block += action.block_amount
			log_requested.emit("Enemy braces! (%d block)" % action.block_amount)
		_:
			push_warning("CombatEnemyAI: tipo de acción desconocido '%s'" % action.action_type)
