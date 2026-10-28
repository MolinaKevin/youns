class_name CombatMapTerrainCollisionPort
extends RefCounted

func obstacles() -> Array[Dictionary]: return []
func obstacle_snapshot() -> Array[Dictionary]: return []
func platforms() -> Array[Dictionary]: return []
func clip_path_at_obstacle(_from: Vector2, to: Vector2) -> Vector2: return to
func is_blocked(_pos: Vector2, _elevation: int = 0, _margin: float = 0.5) -> bool: return false
func is_tile_obstructed(_pos: Vector2, _elevation: int = 0) -> bool: return false
func can_blink_to(_pos: Vector2) -> bool: return false
