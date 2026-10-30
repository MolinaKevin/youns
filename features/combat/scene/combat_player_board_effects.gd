class_name CombatPlayerBoardEffects
extends RefCounted

## Efectos espaciales que atraviesan varias familias de cartas: contacto con
## zonas, caída de árboles, empuje forzado y nova.

var host

func _init(p_host) -> void:
	host = p_host

func apply_player_zone_effects(from: Vector2, to: Vector2) -> void:
	var contact_margin: float = host.board.queries.actors.player_area_contact_radius()
	var zone_fx: Dictionary = host.board.effects.puddle_port.zones.puddle_effects_along(from, to, contact_margin)
	var zone_dmg: Dictionary = host.board.effects.puddle_port.zones.puddle_damage_along(from, to, contact_margin)
	for event in host.zone_effects.apply_path_effects(host.state, zone_fx, zone_dmg, true):
		host.zone_effects.log_zone_effect(event, "combat.log.player.zone", CombatZoneEffectResolver.PLAYER_LOG_TURNS, host.emit_log)

func player_falls_from_tree(burning: bool) -> void:
	var flow: AsyncFlowToken = host.current_flow()
	if not host.is_flow_active(flow) or not host.state.player_in_tree:
		return
	host.state.player_in_tree = false
	host.emit_log("combat.log.player.tree_fall", [host.TREE_FALL_DAMAGE])
	await host.deal_damage_to_player.call(host.TREE_FALL_DAMAGE, true, CombatState.FISICO)
	if not host.is_flow_active(flow):
		return
	if burning and host.state.player_hp > 0:
		var turns: int = host.state.set_player_status("burn", host.TREE_FIRE_BURN_TURNS)
		host.emit_log("combat.log.player.burning_tree_fall", [turns])
	if host.state.player_hp > 0:
		apply_player_zone_effects(host.map_area.player_pos, host.map_area.player_pos)
	host.ui_update_requested.emit()
	host.check_combat_end.call()

func apply_enemy_forced_move(card_name: String, from: Vector2, landing: Vector2, flow: AsyncFlowToken) -> bool:
	var contact_margin: float = host.board.queries.actors.enemy_area_contact_radius()
	var fx: Dictionary = host.board.effects.puddle_port.zones.zone_effects_along(from, landing, contact_margin)
	var zone_dmg: Dictionary = host.board.effects.puddle_port.zones.puddle_damage_along(from, landing, contact_margin)
	var events: Array = host.zone_effects.apply_path_effects(host.state, fx, zone_dmg, false)
	for event in events:
		host.zone_effects.log_zone_effect(event, "combat.log.enemy.forced_zone", CombatZoneEffectResolver.ENEMY_LOG_TURNS, host.emit_log)
	var any_zone: bool = not events.is_empty()
	if fx.get("trap_damage", 0) > 0:
		host.emit_log("combat.log.player.enemy_forced_trap", [card_name, fx["trap_damage"]])
		await host.deal_damage_to_enemy.call(fx["trap_damage"])
		if not host.is_flow_active(flow):
			return any_zone
		any_zone = true
	return any_zone

func execute_nova(card: CardActionLine) -> void:
	var flow: AsyncFlowToken = host.current_flow()
	if not host.is_flow_active(flow):
		return
	var radius: float = host.w(card.primary_range_cells())
	var in_pattern: bool = host.board.selection.targeting.queries.is_enemy_in_card_pattern(card.pattern, host.map_area.player_pos, Vector2(0, 1), radius) if card.pattern != null else host.board.queries.areas.is_enemy_in_area_circle(host.map_area.player_pos, radius)
	if not in_pattern:
		host.emit_log("combat.log.player.nova_no_target", [card.name])
		return
	host.emit_log("combat.log.player.nova_hits_enemy", [card.name, card.damage])
	await host.deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
	if not host.is_flow_active(flow):
		return
	if host.state.enemy_hp <= 0:
		host.check_combat_end.call()
		return
	var from: Vector2 = host.map_area.enemy_pos
	var away: Vector2 = from + (from - host.map_area.player_pos)
	var landing: Vector2 = host.board.push.queries.calculate_push_landing(away, host.w(card.cast_range_cells()))
	host.board.push.execution.push_enemy_to(landing)
	await host.board.enemy_reached_target
	if not host.is_flow_active(flow):
		return
	await apply_enemy_forced_move(card.name, from, landing, flow)
	if not host.is_flow_active(flow):
		return
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()
	host.check_combat_end.call()
