class_name CombatRoundResolver
extends RefCounted

var zone_effects := CombatZoneEffectResolver.new()

## Ordena las reglas de fin de ronda sin conocer UI, animaciones ni corrutinas.
## Combat consume estos eventos, localiza sus mensajes y aplica el daño para
## poder detener la secuencia inmediatamente cuando termina el combate.

func build_events(state: CombatState, map_area: MapArea) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.player_in_tree:
		state.player_in_tree = false
		events.append({
			"kind": "tree_drop",
			"hit": map_area.drop_from_tree(state.player_tree_landing),
			"damage": state.player_tree_drop_damage,
		})
	for hit: Dictionary in map_area.resolve_delayed_zones():
		if hit["enemy"]:
			events.append({"kind": "delayed_zone", "target": "enemy", "hit": hit})
		if hit["player"]:
			events.append({"kind": "delayed_zone", "target": "player", "hit": hit})
		if not hit["enemy"] and not hit["player"]:
			events.append({"kind": "delayed_zone", "target": "none", "hit": hit})
	events.append({"kind": "tick_map_effects"})
	events.append_array(_status_events(state))
	return events

func apply_delayed_zone_impact(state: CombatState, event: Dictionary) -> Array:
	var hit: Dictionary = event["hit"]
	return zone_effects.apply_direct_impact(state, hit["effect"], hit["tick_damage"], event["target"] != "enemy")

func finish_status_event(state: CombatState, event: Dictionary) -> String:
	var field: String = event["field"]
	state.set(field, maxi(0, int(state.get(field)) - 1))
	return event["expired_log_key"] if state.get(field) == 0 else ""

func _status_events(state: CombatState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state.player_burning_turns > 0:
		events.append(_damage_status("player_burning_turns", state.player_burn_damage, CombatState.BURN_DAMAGE_TYPE,
			"combat.status.player_burning_damage", "combat.status.player_burning_expired"))
	if state.player_bleeding_turns > 0:
		events.append(_damage_status("player_bleeding_turns", state.player_bleed_damage, CombatState.BLEED_DAMAGE_TYPE,
			"combat.status.player_bleeding_damage", "combat.status.player_bleeding_expired"))
	if state.player_poison_stacks > 0:
		events.append(_damage_status("player_poison_stacks", state.player_poison_stacks * state.player_poison_damage,
			CombatState.POISON_DAMAGE_TYPE, "combat.status.player_poison_damage", "combat.status.player_poison_expired"))
	for status in [
		["player_wet_turns", "combat.status.player_wet_expired"],
		["player_greasy_turns", "combat.status.player_greasy_expired"],
		["player_entangled_turns", "combat.status.player_entangled_expired"],
		["player_blinded_turns", "combat.status.player_blinded_expired"],
		["player_frozen_turns", "combat.status.player_frozen_expired"],
	]:
		if state.get(status[0]) > 0:
			events.append({"kind": "status_duration", "field": status[0], "expired_log_key": status[1]})
	return events

func _damage_status(field: String, damage: int, damage_type: String, damage_log_key: String, expired_log_key: String) -> Dictionary:
	return {
		"kind": "status_damage", "field": field, "damage": damage, "damage_type": damage_type,
		"damage_log_key": damage_log_key, "expired_log_key": expired_log_key,
	}
