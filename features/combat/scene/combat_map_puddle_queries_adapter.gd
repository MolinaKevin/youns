class_name CombatMapPuddleQueriesAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func puddle_at(pos: Vector2) -> Dictionary: return source.puddle_at(pos)
func puddles() -> Array[Dictionary]: return source.puddles()
func puddle_visual_count() -> int: return source.puddle_visual_count()
func puddles_on_segment(from: Vector2, to: Vector2, effects: Array) -> Array: return source.puddles_on_segment(from, to, effects)
