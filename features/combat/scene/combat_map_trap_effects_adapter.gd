class_name CombatMapTrapEffectsAdapter
extends CombatMapTrapEffectsPort

var source
func _init(value: CombatMapEffectsPort) -> void: source = value
func trigger_traps(pos: Vector2, margin: float = 0.0) -> int: return source.trigger_traps(pos, margin)
func trigger_traps_along(from: Vector2, to: Vector2, margin: float = 0.0) -> int: return source.trigger_traps_along(from, to, margin)
