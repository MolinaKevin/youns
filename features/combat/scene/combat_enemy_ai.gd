class_name CombatEnemyAI
extends RefCounted

var state
var combat: Node
var _strategy: AiStrategy

func setup(p_combat: Node, p_state, strategy: AiStrategy) -> void:
	combat = p_combat
	state  = p_state
	_strategy = strategy

# ── Turn ──────────────────────────────────────────────────────────────────────

func take_turn() -> void:
	var trap_dmg: int = combat.map_area.check_and_trigger_traps(combat.map_area.enemy_pos)
	if trap_dmg > 0:
		combat.deal_damage_to_enemy(trap_dmg)
		combat.log_message("Enemy triggered a trap! %d damage." % trap_dmg)
		if combat.check_combat_end():
			return

	var action: AiAction = _pick_action()
	if action:
		_execute_action(action)

	combat.update_ui()
	pick_intent()

# ── Evaluation ────────────────────────────────────────────────────────────────

func _pick_action() -> AiAction:
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
	var map  = combat.map_area
	var dist: float = map.movement_distance(map.enemy_pos, map.player_pos)
	match cond:
		"always":
			return true
		"player_adjacent":
			return dist <= action.attack_range
		"player_in_range":
			return dist <= action.attack_range \
				and map.has_line_of_sight(map.enemy_pos, map.player_pos)
		"player_out_of_range":
			return dist > action.attack_range \
				or not map.has_line_of_sight(map.enemy_pos, map.player_pos)
		"player_far":
			return dist > 15.0
		"self_hp_low":
			return float(state.enemy_hp) / float(state.enemy_max_hp) < 0.3
		"self_hp_critical":
			return float(state.enemy_hp) / float(state.enemy_max_hp) < 0.15
		"has_los":
			return map.has_line_of_sight(map.enemy_pos, map.player_pos)
	push_warning("CombatEnemyAI: condición desconocida '%s'" % cond)
	return false

func _compute_score(action: AiAction) -> float:
	var score := action.base_score
	if float(state.enemy_hp) / float(state.enemy_max_hp) < 0.3:
		score *= action.score_multiplier_low_hp
	return score

# ── Execution ─────────────────────────────────────────────────────────────────

func _execute_action(action: AiAction) -> void:
	var map = combat.map_area
	match action.action_type:
		"melee_attack":
			combat.deal_damage_to_player(action.damage)
			combat.log_message("Enemy strikes for %d!" % action.damage)
		"range_attack":
			combat.deal_damage_to_player(action.damage)
			combat.log_message("Enemy shoots for %d!" % action.damage)
		"move_toward":
			map.move_enemy_toward(map.player_pos, action.move_range)
			combat.log_message("Enemy moves closer.")
		"move_away":
			var away_dir: Vector2 = (map.enemy_pos - map.player_pos).normalized()
			var target: Vector2   = map.enemy_pos + away_dir * action.move_range
			target.x = clampf(target.x, 0.0, map.WORLD_W)
			target.y = clampf(target.y, 0.0, map.WORLD_H)
			map.move_enemy_toward(target, action.move_range)
			combat.log_message("Enemy retreats!")
		"block":
			state.enemy_block += action.block_amount
			combat.log_message("Enemy braces! (%d block)" % action.block_amount)
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
