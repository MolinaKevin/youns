class_name CombatEnemyStrategyAi
extends RefCounted

## Sin mazo, el enemigo usa esta máquina de fases/condiciones (AiStrategy/
## AiPhase/AiAction/AiCondition) para elegir qué hacer. Es la otra de las dos
## "IA" de CombatEnemyAI — ver CombatEnemyCardAi para la que usa mazo. `host`
## es el CombatEnemyAI dueño exclusivo de esta instancia.

var host: CombatEnemyAI
var strategy: AiStrategy
var current_phase: String = ""

func _init(p_host: CombatEnemyAI) -> void:
	host = p_host

func configure(p_strategy: AiStrategy) -> void:
	strategy = p_strategy
	if strategy != null and strategy.initial_phase != "":
		current_phase = strategy.initial_phase

func evaluate_transitions() -> void:
	if strategy == null:
		return
	for trans in strategy.transitions:
		if trans.from_phase != current_phase:
			continue
		if _conditions_met_list(trans.conditions):
			current_phase = trans.target_phase
			return

func pick_action() -> AiAction:
	if strategy == null:
		return null
	if current_phase != "":
		var phase := _get_phase(current_phase)
		if phase == null:
			return null
		return _pick_best_from(phase.actions)
	return _pick_best_from(strategy.actions)

func _get_phase(phase_name: String) -> AiPhase:
	for phase in strategy.phases:
		if phase.phase_name == phase_name:
			return phase
	return null

func _pick_best_from(actions: Array) -> AiAction:
	var best: AiAction = null
	var best_score: float = -INF
	for action in actions:
		if not _conditions_met(action):
			continue
		var score := score_action(action)
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
	var dist: float = host.map_area.queries.movement_distance(host.map_area.enemy_pos, host.map_area.player_pos)
	match cond.type:
		"always":
			return true
		"player_adjacent":
			return dist <= cond.check_range
		"player_in_range":
			return dist <= cond.check_range \
				and host.map_area.queries.has_line_of_sight(host.map_area.enemy_pos, host.map_area.player_pos)
		"player_out_of_range":
			return dist > cond.check_range \
				or not host.map_area.queries.has_line_of_sight(host.map_area.enemy_pos, host.map_area.player_pos)
		"player_far":
			return dist > 15.0
		"self_hp_low":
			return float(host.state.enemy_hp) / float(host.state.enemy_max_hp) < 0.3
		"self_hp_critical":
			return float(host.state.enemy_hp) / float(host.state.enemy_max_hp) < 0.15
		"has_los":
			return host.map_area.queries.has_line_of_sight(host.map_area.enemy_pos, host.map_area.player_pos)
		"player_hidden":
			return host._had_los \
				and not host.map_area.queries.has_line_of_sight(host.map_area.enemy_pos, host.map_area.player_pos)
	push_warning("CombatEnemyAI: condición desconocida '%s'" % cond.type)
	return false

func score_action(action: AiAction) -> float:
	var score := action.base_score
	if float(host.state.enemy_hp) / float(host.state.enemy_max_hp) < 0.3:
		score *= action.score_multiplier_low_hp
	return score

func execute_action(action: AiAction) -> void:
	match action.action_type:
		"melee_attack":
			if host.state.player_in_tree:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.cannot_reach_tree")
				return
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.strikes", [action.damage])
			await host.deal_damage_to_player.call(action.damage, false, action.damage_type)
			await host._try_player_counter()
		"range_attack":
			if host.state.enemy_blinded_turns > 0 and host.map_area.queries.movement_distance(host.map_area.enemy_pos, host.map_area.player_pos) > 2.0:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.blinded_no_ranged")
				return
			if host.state.player_in_tree:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.cannot_reach_tree")
				return
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.shoots", [action.damage])
			await host.deal_damage_to_player.call(action.damage, false, action.damage_type)
		"move_toward":
			await host._move_enemy(host.map_area.player_pos, action.move_range, "combat.log.enemy.moves_closer")
		"move_away":
			await host._move_enemy(host._retreat_target(action.move_range), action.move_range, "combat.log.enemy.retreats")
		"move_to_last_known":
			await host._move_enemy(host.last_known_player_pos, action.move_range, "combat.log.enemy.searches")
		"block":
			host.state.enemy_block += action.block_amount
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.braces", [action.block_amount])
		"ward":
			host.state.enemy_ward += action.block_amount
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.ward", [action.block_amount])
		_:
			push_warning("CombatEnemyAI: tipo de acción desconocido '%s'" % action.action_type)
