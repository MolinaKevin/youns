class_name CombatMapPushQueriesAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func is_pos_in_push_cone(pos: Vector2, reach: float) -> bool: return source.is_pos_in_push_cone(pos, reach)
func calculate_push_landing(target: Vector2, reach: float) -> Vector2: return source.calculate_push_landing(target, reach)
func calculate_drag_landing(target: Vector2, distance: float) -> Vector2: return source.calculate_drag_landing(target, distance)
