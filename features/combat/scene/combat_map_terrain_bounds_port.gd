class_name CombatMapTerrainBoundsPort
extends RefCounted

func is_inside_bounds(_pos: Vector2, _margin: float = 0.0) -> bool: return false
func clamp_to_bounds(pos: Vector2, _margin: float = 0.0) -> Vector2: return pos
func bounds_travel_fraction(_from: Vector2, _to: Vector2, _margin: float) -> float: return 0.0
func elevation_at(_pos: Vector2) -> int: return 0
func player_height_at(_pos: Vector2, _elevation: int) -> float: return 0.0
func elevation_height(elevation: int) -> float: return float(elevation) * 1.5
func height_at(_pos: Vector2) -> float: return 0.0
