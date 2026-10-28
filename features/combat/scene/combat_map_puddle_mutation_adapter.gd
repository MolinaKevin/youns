class_name CombatMapPuddleMutationAdapter
extends CombatMapPuddleMutationPort

var source
func _init(value) -> void: source = value
func move_puddle(zone: Dictionary, to: Vector2) -> Dictionary: return source.move_puddle(zone, to)
func convert_puddles(center: Vector2, radius: float, effects: Array, to_effect: String) -> int: return source.convert_puddles(center, radius, effects, to_effect)
func tick_puddles() -> void: source.tick_puddles()
