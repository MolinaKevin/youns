class_name CombatMapPushQueriesPort
extends RefCounted
func is_pos_in_push_cone(_pos: Vector2, _reach: float) -> bool: return false
func calculate_push_landing(target: Vector2, _reach: float) -> Vector2: return target
func calculate_drag_landing(target: Vector2, _distance: float) -> Vector2: return target
