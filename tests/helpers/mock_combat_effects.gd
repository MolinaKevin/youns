class_name MockCombatEffects
extends CombatMapEffectsPort

## Doble independiente de efectos para que las suites no dependan del fixture
## monolítico de CombatTestCase.
var owner

func _init() -> void:
	traps = CombatMapTrapEffectsAdapter.new(self)
	puddle_port = CombatMapPuddleEffectsAdapter.new(self)
	delayed = CombatMapDelayedEffectsAdapter.new(self)

func trigger_traps(_pos: Vector2, _margin: float = 0.0) -> int: return 0
func trigger_traps_along(_from: Vector2, _to: Vector2, _margin: float = 0.0) -> int: return 0
func puddle_at(_pos: Vector2) -> Dictionary: return {}
func puddles() -> Array[Dictionary]: return []
func puddle_visual_count() -> int: return 0
func move_puddle(zone: Dictionary, _to: Vector2) -> Dictionary: return zone
func convert_puddles(_center: Vector2, _radius: float, _from_effects: Array, _to_effect: String) -> int: return 0
func puddles_on_segment(_from: Vector2, _to: Vector2, _effects: Array) -> Array: return []
func puddle_damage_along(_from: Vector2, _to: Vector2, _margin: float = 0.0) -> Dictionary: return owner.puddle_damage_result
func puddle_effects_along(_from: Vector2, _to: Vector2, _margin: float = 0.0) -> Dictionary: return owner.puddle_effects_result
func zone_effects_along(_from: Vector2, _to: Vector2, _margin: float = 0.0) -> Dictionary: return owner.puddle_effects_result
func tick_puddles() -> void: pass
func place_delayed_zone(pos: Vector2, radius: float, damage: int, _name: String, rounds: int = 1, effect: String = "", turns: int = 0) -> void:
	owner.place_delayed_zone_calls.append({"pos": pos, "radius": radius, "damage": damage, "delay": rounds, "effect": effect, "duration": turns})
func resolve_delayed_zones() -> Array[CombatDelayedImpact]: return []
func delayed_zones() -> Array[CombatDelayedZone]: return []
func blink_player_to(pos: Vector2) -> void: owner.blink_calls.append(pos)
