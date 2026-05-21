class_name CombatEnemyAI
extends RefCounted

var state
var map_area: Node
var _strategy: AiStrategy

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

# ── Turn ──────────────────────────────────────────────────────────────────────

func take_turn() -> void:
	var trap_dmg: int = map_area.check_and_trigger_traps(map_area.enemy_pos)
	if trap_dmg > 0:
		await _deal_damage_to_enemy.call(trap_dmg)
		log_requested.emit("Enemy triggered a trap! %d damage." % trap_dmg)
		if _check_combat_end.call():
			return

	var action: AiAction = _pick_action()
	if action:
		await _execute_action(action)

	ui_update_requested.emit()
	pick_intent()

# ── Evaluation ────────────────────────────────────────────────────────────────

func _pick_action() -> AiAction:
	if _strategy == null:
		return null
	var best: AiAction = null
	var best_score := -INF
	for action in _strategy.actions:
		if not _conditions_met(action):
			continue
		var score := _compute_score(action)
		if score > best_score:
			best_score = score
			best       = action
	return best

func _conditions_met(action: AiAction) -> bool:
	for cond in action.conditions:
		if not _eval_condition(cond, action):
			return false
	return true

func _eval_condition(cond: String, action: AiAction) -> bool:
	var dist: float = map_area.movement_distance(map_area.enemy_pos, map_area.player_pos)
	match cond:
		"always":
			return true
		"player_adjacent":
			return dist <= action.attack_range
		"player_in_range":
			return dist <= action.attack_range \
				and map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
		"player_out_of_range":
			return dist > action.attack_range \
				or not map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
		"player_far":
			return dist > 15.0
		"self_hp_low":
			return float(state.enemy_hp) / float(state.enemy_max_hp) < 0.3
		"self_hp_critical":
			return float(state.enemy_hp) / float(state.enemy_max_hp) < 0.15
		"has_los":
			return map_area.has_line_of_sight(map_area.enemy_pos, map_area.player_pos)
	push_warning("CombatEnemyAI: condición desconocida '%s'" % cond)
	return false

func _compute_score(action: AiAction) -> float:
	var score := action.base_score
	if float(state.enemy_hp) / float(state.enemy_max_hp) < 0.3:
		score *= action.score_multiplier_low_hp
	return score

# ── Execution ─────────────────────────────────────────────────────────────────

func _execute_action(action: AiAction) -> void:
	match action.action_type:
		"melee_attack":
			log_requested.emit("Enemy strikes for %d!" % action.damage)
			await _deal_damage_to_player.call(action.damage)
		"range_attack":
			log_requested.emit("Enemy shoots for %d!" % action.damage)
			await _deal_damage_to_player.call(action.damage)
		"move_toward":
			map_area.move_enemy_toward(map_area.player_pos, action.move_range)
			log_requested.emit("Enemy moves closer.")
		"move_away":
			var away_dir: Vector2 = (map_area.enemy_pos - map_area.player_pos).normalized()
			var target: Vector2   = map_area.enemy_pos + away_dir * action.move_range
			target.x = clampf(target.x, 0.0, map_area.WORLD_W)
			target.y = clampf(target.y, 0.0, map_area.WORLD_H)
			map_area.move_enemy_toward(target, action.move_range)
			log_requested.emit("Enemy retreats!")
		"block":
			state.enemy_block += action.block_amount
			log_requested.emit("Enemy braces! (%d block)" % action.block_amount)
		_:
			push_warning("CombatEnemyAI: tipo de acción desconocido '%s'" % action.action_type)

# ── Intent (preview del próximo turno) ───────────────────────────────────────

func pick_intent() -> void:
	var action: AiAction = _pick_action()
	if action == null:
		state.enemy_intent = {"type": "wait", "value": 0}
		return
	match action.action_type:
		"melee_attack":
			state.enemy_intent = {"type": "attack", "value": action.damage}
		"range_attack":
			state.enemy_intent = {"type": "range_attack", "value": action.damage}
		"move_toward":
			state.enemy_intent = {"type": "move", "value": 0}
		"move_away":
			state.enemy_intent = {"type": "retreat", "value": 0}
		"block":
			state.enemy_intent = {"type": "block", "value": action.block_amount}
		_:
			state.enemy_intent = {"type": "wait", "value": 0}
