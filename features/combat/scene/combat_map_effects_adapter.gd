class_name CombatMapEffectsAdapter
extends CombatMapEffectsPort

## Adaptador de efectos construido sobre los sistemas concretos del tablero.
## Expone sólo las consultas y acciones de efectos del tablero.
var _map: CombatMapArea
var _trap_system: TrapSystem
var _puddle_system: PuddleSystem
var _spell_system: CombatSpellSystem

func _init(map: CombatMapArea, trap_system: TrapSystem, puddle_system: PuddleSystem, spell_system: CombatSpellSystem) -> void:
	_map = map
	_trap_system = trap_system
	_puddle_system = puddle_system
	_spell_system = spell_system
	traps = CombatMapTrapEffectsAdapter.new(self)
	puddle_port = CombatMapPuddleEffectsAdapter.new(self)
	delayed = CombatMapDelayedEffectsAdapter.new(self)

func trigger_traps(pos: Vector2, contact_margin: float = 0.0) -> int:
	return _trap_system.check_and_trigger_traps(pos, contact_margin)

func trigger_traps_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> int:
	return _trap_system.check_traps_along_segment(from, to, contact_margin)

func puddle_at(pos: Vector2) -> Dictionary: return _puddle_system.get_puddle_at(pos)
func puddles() -> Array[Dictionary]: return _puddle_system.zones.duplicate(true)
func puddle_visual_count() -> int: return _puddle_system.visuals.size()
func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary: return _puddle_system.move_puddle(zone, to)
func convert_puddles(center: Vector2, radius: float, from_effects: Array, to_effect: String) -> int:
	return _puddle_system.convert_puddles(center, radius, from_effects, to_effect)
func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array:
	return _puddle_system.puddles_on_segment(from, to, effects)
func puddle_damage_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	return _puddle_system.get_puddle_damage_along(from, to, contact_margin)
func puddle_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	return _puddle_system.get_puddle_effects_along(from, to, contact_margin)
func zone_effects_along(from: Vector2, to: Vector2, contact_margin: float = 0.0) -> Dictionary:
	var effects := puddle_effects_along(from, to, contact_margin)
	effects["trap_damage"] = trigger_traps_along(from, to, contact_margin)
	return effects
func tick_puddles() -> void: _puddle_system.tick_puddles()

func place_delayed_zone(pos: Vector2, radius: float, damage: int, name: String, rounds: int = 1, effect: String = "", puddle_turns: int = 0) -> void:
	_spell_system.place_delayed_zone(pos, radius, damage, name, rounds, effect, puddle_turns)
func resolve_delayed_zones() -> Array[CombatDelayedImpact]: return _spell_system.resolve_delayed_zones()
func delayed_zones() -> Array[CombatDelayedZone]: return _spell_system.delayed_zones
func blink_player_to(pos: Vector2) -> void:
	_map.player_pos = pos
	_map.player_elevation = _map.terrain.geometry.bounds.elevation_at(pos)
	_map.actors.state.targets.sync_targets()
