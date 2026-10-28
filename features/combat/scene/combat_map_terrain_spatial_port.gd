class_name CombatMapTerrainSpatialPort
extends RefCounted

func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool: return false
func movement_distance(from: Vector2, to: Vector2) -> float: return from.distance_to(to)
func player_contact_radius() -> float: return 0.0
func enemy_contact_radius() -> float: return 0.0
