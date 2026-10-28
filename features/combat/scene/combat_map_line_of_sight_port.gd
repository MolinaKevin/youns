class_name CombatMapLineOfSightPort
extends RefCounted
func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool: return false
func line_of_sight_clear(_from: Vector2, _to: Vector2, _block_rocks: bool, _block_bridges: bool, _from_elevation: int, _to_elevation: int) -> bool: return false
