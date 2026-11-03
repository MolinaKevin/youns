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
	var dist: float = host.board.queries.movement_distance(host.board.state.enemy_position(), host.board.state.player_position())
	match cond.type:
		AiCondition.TYPE_ALWAYS:
			return true
		AiCondition.TYPE_PLAYER_ADJACENT:
			return dist <= cond.check_range
		AiCondition.TYPE_PLAYER_IN_RANGE:
			return dist <= cond.check_range \
			and host.board.queries.has_line_of_sight(host.board.state.enemy_position(), host.board.state.player_position())
		AiCondition.TYPE_PLAYER_OUT_OF_RANGE:
			return dist > cond.check_range \
			or not host.board.queries.has_line_of_sight(host.board.state.enemy_position(), host.board.state.player_position())
		AiCondition.TYPE_PLAYER_FAR:
			return dist > 15.0
		AiCondition.TYPE_SELF_HP_LOW:
			return float(host.state.enemy_hp) / float(host.state.enemy_max_hp) < 0.3
		AiCondition.TYPE_SELF_HP_CRITICAL:
			return float(host.state.enemy_hp) / float(host.state.enemy_max_hp) < 0.15
		AiCondition.TYPE_HAS_LOS:
			return host.board.queries.has_line_of_sight(host.board.state.enemy_position(), host.board.state.player_position())
		AiCondition.TYPE_PLAYER_HIDDEN:
			return host._had_los \
				and not host.board.queries.has_line_of_sight(host.board.state.enemy_position(), host.board.state.player_position())
	push_warning("CombatEnemyAI: condición desconocida '%s'" % cond.type)
	return false

func score_action(action: AiAction) -> float:
	var score := action.base_score
	if float(host.state.enemy_hp) / float(host.state.enemy_max_hp) < 0.3:
		score *= action.score_multiplier_low_hp
	return score

func execute_action(action: AiAction) -> void:
	match action.action_type:
		AiAction.TYPE_MELEE_ATTACK:
			if host.state.player_in_tree:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.cannot_reach_tree")
				return
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.strikes", [action.damage])
			await host.deal_damage_to_player.call(action.damage, false, action.damage_type)
			await host._try_player_counter()
		AiAction.TYPE_RANGE_ATTACK:
			if host.state.enemy_blinded_turns > 0 and host.board.queries.movement_distance(host.board.state.enemy_position(), host.board.state.player_position()) > 2.0:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.blinded_no_ranged")
				return
			if host.state.player_in_tree:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.cannot_reach_tree")
				return
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.shoots", [action.damage])
			await host.deal_damage_to_player.call(action.damage, false, action.damage_type)
		AiAction.TYPE_MOVE_TOWARD:
			await host._move_enemy(host.board.state.player_position(), action.move_range, "combat.log.enemy.moves_closer")
		AiAction.TYPE_MOVE_AWAY:
			await host._move_enemy(host._retreat_target(action.move_range), action.move_range, "combat.log.enemy.retreats")
		AiAction.TYPE_MOVE_TO_LAST_KNOWN:
			await host._move_enemy(host.last_known_player_pos, action.move_range, "combat.log.enemy.searches")
		AiAction.TYPE_BLOCK:
			host.state.enemy_block += action.block_amount
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.braces", [action.block_amount])
		AiAction.TYPE_WARD:
			host.state.enemy_ward += action.block_amount
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.ward", [action.block_amount])
		_:
			push_warning("CombatEnemyAI: tipo de acción desconocido '%s'" % action.action_type)
