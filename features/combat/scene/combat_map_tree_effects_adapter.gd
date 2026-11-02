class_name CombatMapTreeEffectsAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func ignite_trees_in_circle(center: Vector2, radius: float) -> int: return source.ignite_trees_in_circle(center, radius)
func ignite_trees_in_cone(origin: Vector2, direction: Vector2, reach: float, angle: float) -> int: return source.ignite_trees_in_cone(origin, direction, reach, angle)
func extinguish_trees_in_circle(center: Vector2, radius: float) -> int: return source.extinguish_trees_in_circle(center, radius)
func tick_trees() -> void: source.tick_trees()
