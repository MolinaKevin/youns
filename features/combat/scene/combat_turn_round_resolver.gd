class_name CombatTurnRoundResolver
extends RefCounted

## Cierra la ronda y aplica sus eventos. La coordinación de cartas permanece
## en CombatTurnFlow; este helper concentra sólo la fase de resolución.

var host

func _init(p_host) -> void:
	host = p_host

func reset_turn(flow: AsyncFlowToken) -> void:
	for event in host.round_resolver.build_events(host.state, host.map_area):
		if await resolve_event(event, flow):
			return
		if not host.is_flow_active(flow):
			return
	host.player_actions.reset()
	host.deck_manager.reset_turn(Combat.HAND_SIZE, host.turn.kept_indices)
	host.turn.kept_indices.clear()
	host.turn.turn_hand_indices.clear()
	host.refresh_hand()
	host.update_ui()

func resolve_event(event: CombatRoundEvent, flow: AsyncFlowToken) -> bool:
	match event.kind:
		"tree_drop":
			if event.hit:
				host.log_message(LocalizationState.t("combat.tree_drop.enemy_hit", [event.damage]))
				await host._damage.deal_to_enemy(event.damage, false, CombatState.FISICO)
				if not host.is_flow_active(flow) or host._result_flow.check_combat_end(): return true
			else:
				host.log_message(LocalizationState.t("combat.tree_drop.descend"))
			host.player_actions.apply_player_zone_effects(host.board.state.player_position(), host.board.state.player_position())
		"delayed_zone":
			if await resolve_delayed_zone(event, flow): return true
		"tick_map_effects":
			host.board.effects.puddle_port.mutation.tick_puddles()
			host.board.obstacles.tick_trees()
		"status_damage":
			host.log_message(LocalizationState.t(event.damage_log_key, [event.damage]))
			await host._damage.deal_to_player(event.damage, true, event.damage_type)
			if not host.is_flow_active(flow) or host._result_flow.check_combat_end(): return true
			log_expired(host.round_resolver.finish_status_event(host.state, event))
		"status_duration":
			log_expired(host.round_resolver.finish_status_event(host.state, event))
	return false

func resolve_delayed_zone(event: CombatRoundEvent, flow: AsyncFlowToken) -> bool:
	var hit := event.zone_hit
	var on_enemy := event.target == "enemy"
	if event.target == "none":
		host.log_message(LocalizationState.t("combat.delayed_zone.miss", [hit.display_name, hit.damage]))
		return false
	var target_name := "enemy" if on_enemy else "player"
	host.log_message(LocalizationState.t("combat.delayed_zone.%s_hit" % target_name, [hit.display_name, hit.damage]))
	if on_enemy:
		await host._damage.deal_to_enemy(hit.damage, true, CombatState.MAGICO)
	else:
		await host._damage.deal_to_player(hit.damage, true, CombatState.MAGICO)
	if not host.is_flow_active(flow) or host._result_flow.check_combat_end(): return true
	log_delayed_impact(host.round_resolver.apply_delayed_zone_impact(host.state, event), on_enemy)
	return false

func log_delayed_impact(impact: Array, on_enemy: bool) -> void:
	if not impact.is_empty() and impact[1] > 0:
		var key := "combat.status.enemy_applied" if on_enemy else "combat.status.player_applied"
		var status := str(impact[0])
		var status_key := "combat.status_name." + status
		var status_name: String = LocalizationState.t(status_key) if LocalizationState.has_key(status_key) else str(CombatPlayerActions.STATUS_NAMES.get(status, status))
		host.log_message(LocalizationState.t(key, [status_name, impact[1]]))

func log_expired(key: String) -> void:
	if not key.is_empty(): host.log_message(LocalizationState.t(key))
