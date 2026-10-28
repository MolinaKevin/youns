class_name CombatMapPuddleZoneEffectsAdapter
extends CombatMapPuddleZoneEffectsPort

var source
func _init(value) -> void: source = value
func puddle_damage_along(from: Vector2, to: Vector2, margin: float = 0.0) -> Dictionary: return source.puddle_damage_along(from, to, margin)
func puddle_effects_along(from: Vector2, to: Vector2, margin: float = 0.0) -> Dictionary: return source.puddle_effects_along(from, to, margin)
func zone_effects_along(from: Vector2, to: Vector2, margin: float = 0.0) -> Dictionary: return source.zone_effects_along(from, to, margin)
