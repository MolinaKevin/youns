class_name CombatZoneEffectResolver
extends RefCounted
const CombatEffects := preload("res://features/combat/scene/combat_effect.gd")

## Reglas compartidas de estados causados por charcos. El mapa sólo informa
## qué efectos tocó una unidad; los llamadores deciden cómo mostrarlos.

func apply_path_effects(state: CombatState, effects: Dictionary, damages: Dictionary, on_player: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for effect in CombatEffects.ZONE_TYPES:
		if not effects.get(effect, false):
			continue
		if effect == CombatEffects.BLOODY_ICE:
			var frozen := _apply_status(state, CombatEffects.FREEZE, 2, damages, on_player)
			var bleeding := _apply_status(state, CombatEffects.BLEED, 3, {CombatEffects.BLOOD: damages.get(CombatEffects.BLOODY_ICE, 0)}, on_player)
			events.append({"effect": effect, "turns": maxi(frozen, bleeding)})
			continue
		var rule := CombatEffects.path_rule(effect)
		var turns := _apply_status(state, rule["status"], rule["turns"], damages, on_player, rule.get("refresh", false))
		if turns > 0 or effect == CombatEffects.WET:
			events.append({"effect": effect, "turns": turns})
	return events

func apply_direct_impact(state: CombatState, effect: String, tick_damage: int, on_player: bool) -> Array:
	var rule := CombatEffects.path_rule(effect)
	if effect not in CombatEffects.DIRECT_IMPACT_EFFECTS or rule.is_empty():
		return []
	var status: String = rule["status"]
	var damages := {effect: tick_damage}
	var turns := _apply_status(state, status, rule["turns"], damages, on_player, true)
	return [status, turns] if turns > 0 else []

func _apply_status(state: CombatState, status: String, base_turns: int, damages: Dictionary, on_player: bool, refresh: bool = false) -> int:
	if not refresh and state.status_value(status, on_player) > 0:
		return 0
	var damage := int(damages.get(CombatEffects.damage_zone(status), 0))
	if status == CombatEffects.BURN:
		state.set_status_damage(status, on_player, damage if damage > 0 else CombatState.BURN_DAMAGE)
	elif status == CombatEffects.BLEED:
		state.set_status_damage(status, on_player, damage if damage > 0 else CombatState.BLEED_DAMAGE)
	elif status == CombatEffects.POISON:
		state.set_status_damage(status, on_player, damage if damage > 0 else CombatState.POISON_DAMAGE_PER_STACK)
	return state.set_player_status(status, base_turns) if on_player else state.set_enemy_status(status, base_turns)

func _path_status(effect: String) -> String:
	return {"grease": "slow", "vine": "entangle", "sand": "blind", "ice": "freeze", "dark_smoke": "blind"}.get(effect, effect if effect != "fire" else "burn")

func _path_turns(effect: String) -> int:
	return {"wet": 3, "fire": 3, "grease": 3, "vine": 2, "blood": 4, "poison": 3, "sand": 2, "ice": 2, "dark_smoke": 3}.get(effect, 0)

## Efectos de charco que muestran la duración en su mensaje cuando le tocan
## al jugador (todos menos bloody_ice, que no tiene "turns" propio).
const PLAYER_LOG_TURNS := [CombatEffects.WET, CombatEffects.FIRE, CombatEffects.GREASE, CombatEffects.VINE,
	CombatEffects.BLOOD, CombatEffects.POISON, CombatEffects.SAND, CombatEffects.ICE, CombatEffects.DARK_SMOKE]
## Los mismos efectos, pero cuando le tocan al enemigo (natural o forzado):
## sólo enredadera/arena/hielo muestran turnos, el resto sólo avisa que pasó.
const ENEMY_LOG_TURNS := [CombatEffects.VINE, CombatEffects.SAND, CombatEffects.ICE]

## Traduce un evento de apply_path_effects()/apply_direct_impact() a la clave
## de log y los argumentos que le corresponden, y lo entrega a log_fn (el
## emit_log(key, args) de quien llama). Antes esto era un match de 10 casos casi
## idéntico, repetido tres veces (jugador, enemigo, enemigo forzado).
func log_zone_effect(event: Dictionary, key_prefix: String, turn_effects: Array, log_fn: Callable) -> void:
	var effect: String = event["effect"]
	var args := [event["turns"]] if effect in turn_effects else []
	log_fn.call("%s.%s" % [key_prefix, effect], args)
