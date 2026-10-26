class_name CombatRoundResolver
extends RefCounted

var zone_effects := CombatZoneEffectResolver.new()

## Ordena las reglas de fin de ronda sin conocer UI, animaciones ni corrutinas.
## Combat consume estos eventos, localiza sus mensajes y aplica el daño para
## poder detener la secuencia inmediatamente cuando termina el combate.

func build_events(state: CombatState, map_area: MapArea) -> Array[CombatRoundEvent]:
	var events: Array[CombatRoundEvent] = []
	if state.player_in_tree:
		state.player_in_tree = false
		var tree_drop := CombatRoundEvent.new()
		tree_drop.kind = "tree_drop"
		tree_drop.hit = map_area.interactions.drop_from_tree(state.player_tree_landing)
		tree_drop.damage = state.player_tree_drop_damage
		events.append(tree_drop)
	for hit: Dictionary in map_area.interactions.resolve_delayed_zones():
		if hit["enemy"]:
			events.append(_delayed_zone_event("enemy", hit))
		if hit["player"]:
			events.append(_delayed_zone_event("player", hit))
		if not hit["enemy"] and not hit["player"]:
			events.append(_delayed_zone_event("none", hit))
	var tick := CombatRoundEvent.new()
	tick.kind = "tick_map_effects"
	events.append(tick)
	events.append_array(_status_events(state))
	return events

func _delayed_zone_event(target: String, hit: Dictionary) -> CombatRoundEvent:
	var event := CombatRoundEvent.new()
	event.kind = "delayed_zone"
	event.target = target
	event.zone_hit = hit
	return event

func apply_delayed_zone_impact(state: CombatState, event: CombatRoundEvent) -> Array:
	return zone_effects.apply_direct_impact(state, event.zone_hit["effect"], event.zone_hit["tick_damage"], event.target != "enemy")

func finish_status_event(state: CombatState, event: CombatRoundEvent) -> String:
	var remaining := maxi(0, state.status_value(event.effect, true) - 1)
	state.set_status_value(event.effect, true, remaining)
	return event.expired_log_key if remaining == 0 else ""

func _status_events(state: CombatState) -> Array[CombatRoundEvent]:
	var events: Array[CombatRoundEvent] = []
	if state.player_burning_turns > 0:
		events.append(_damage_status(CombatEffect.BURN, state.player_burn_damage, CombatState.BURN_DAMAGE_TYPE,
			"combat.status.player_burning_damage", "combat.status.player_burning_expired"))
	if state.player_bleeding_turns > 0:
		events.append(_damage_status(CombatEffect.BLEED, state.player_bleed_damage, CombatState.BLEED_DAMAGE_TYPE,
			"combat.status.player_bleeding_damage", "combat.status.player_bleeding_expired"))
	if state.player_poison_stacks > 0:
		events.append(_damage_status(CombatEffect.POISON, state.player_poison_stacks * state.player_poison_damage,
			CombatState.POISON_DAMAGE_TYPE, "combat.status.player_poison_damage", "combat.status.player_poison_expired"))
	for status in [
		[CombatEffect.WET, "combat.status.player_wet_expired"],
		[CombatEffect.SLOW, "combat.status.player_greasy_expired"],
		[CombatEffect.ENTANGLE, "combat.status.player_entangled_expired"],
		[CombatEffect.BLIND, "combat.status.player_blinded_expired"],
		[CombatEffect.FREEZE, "combat.status.player_frozen_expired"],
	]:
		if state.status_value(status[0], true) > 0:
			var event := CombatRoundEvent.new()
			event.kind = "status_duration"
			event.effect = status[0]
			event.expired_log_key = status[1]
			events.append(event)
	return events

func _damage_status(effect: String, damage: int, damage_type: String, damage_log_key: String, expired_log_key: String) -> CombatRoundEvent:
	var event := CombatRoundEvent.new()
	event.kind = "status_damage"
	event.effect = effect
	event.damage = damage
	event.damage_type = damage_type
	event.damage_log_key = damage_log_key
	event.expired_log_key = expired_log_key
	return event
