class_name CombatZoneEffectResolver
extends RefCounted

## Reglas compartidas de estados causados por charcos. El mapa sólo informa
## qué efectos tocó una unidad; los llamadores deciden cómo mostrarlos.

const PATH_EFFECTS := ["wet", "fire", "grease", "vine", "blood", "poison", "sand", "ice", "bloody_ice", "dark_smoke"]
const IMPACTS := {
	"wet": ["wet", 3], "fire": ["burn", 3], "poison": ["poison", 3], "blood": ["bleed", 4],
	"grease": ["slow", 3], "vine": ["entangle", 2], "sand": ["blind", 2], "ice": ["freeze", 2],
}

func apply_path_effects(state: CombatState, effects: Dictionary, damages: Dictionary, on_player: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for effect in PATH_EFFECTS:
		if not effects.get(effect, false):
			continue
		if effect == "bloody_ice":
			var frozen := _apply_status(state, "freeze", 2, damages, on_player)
			var bleeding := _apply_status(state, "bleed", 3, {"blood": damages.get("bloody_ice", 0)}, on_player)
			events.append({"effect": effect, "turns": maxi(frozen, bleeding)})
			continue
		var status := _path_status(effect)
		var turns := _apply_status(state, status, _path_turns(effect), damages, on_player, effect == "wet")
		if turns > 0 or effect == "wet":
			events.append({"effect": effect, "turns": turns})
	return events

func apply_direct_impact(state: CombatState, effect: String, tick_damage: int, on_player: bool) -> Array:
	if not IMPACTS.has(effect):
		return []
	var status: String = IMPACTS[effect][0]
	var damages := {effect: tick_damage}
	var turns := _apply_status(state, status, IMPACTS[effect][1], damages, on_player, true)
	return [status, turns] if turns > 0 else []

func _apply_status(state: CombatState, status: String, base_turns: int, damages: Dictionary, on_player: bool, refresh: bool = false) -> int:
	var field := _status_field(status, on_player)
	if not refresh and int(state.get(field)) > 0:
		return 0
	var damage := int(damages.get(_damage_effect(status), 0))
	if status == "burn":
		state.set("player_burn_damage" if on_player else "enemy_burn_damage", damage if damage > 0 else CombatState.BURN_DAMAGE)
	elif status == "bleed":
		state.set("player_bleed_damage" if on_player else "enemy_bleed_damage", damage if damage > 0 else CombatState.BLEED_DAMAGE)
	elif status == "poison":
		state.set("player_poison_damage" if on_player else "enemy_poison_damage", damage if damage > 0 else CombatState.POISON_DAMAGE_PER_STACK)
	return state.set_player_status(status, base_turns) if on_player else state.set_enemy_status(status, base_turns)

func _path_status(effect: String) -> String:
	return {"grease": "slow", "vine": "entangle", "sand": "blind", "ice": "freeze", "dark_smoke": "blind"}.get(effect, effect if effect != "fire" else "burn")

func _path_turns(effect: String) -> int:
	return {"wet": 3, "fire": 3, "grease": 3, "vine": 2, "blood": 4, "poison": 3, "sand": 2, "ice": 2, "dark_smoke": 3}.get(effect, 0)

func _status_field(status: String, on_player: bool) -> String:
	var prefix := "player_" if on_player else "enemy_"
	return prefix + {"wet": "wet_turns", "burn": "burning_turns", "slow": "greasy_turns", "entangle": "entangled_turns", "bleed": "bleeding_turns", "poison": "poison_stacks", "blind": "blinded_turns", "freeze": "frozen_turns"}[status]

func _damage_effect(status: String) -> String:
	return {"burn": "fire", "bleed": "blood", "poison": "poison"}.get(status, "")
