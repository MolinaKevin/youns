class_name CombatMapTerrainBoundsAdapter
extends RefCounted

var source: CombatMapTerrain
func _init(value: CombatMapTerrain = null) -> void: source = value
func is_inside_bounds(pos: Vector2, margin: float = 0.0) -> bool: return source.is_inside_bounds(pos, margin)
func clamp_to_bounds(pos: Vector2, margin: float = 0.0) -> Vector2: return source.clamp_to_bounds(pos, margin)
func bounds_travel_fraction(from: Vector2, to: Vector2, margin: float) -> float: return source.bounds_travel_fraction(from, to, margin)
func elevation_at(pos: Vector2) -> int: return source.elevation_at(pos)
func player_height_at(pos: Vector2, elevation: int) -> float: return source.player_height_at(pos, elevation)
func elevation_height(elevation: int) -> float: return source.elevation_height(elevation)
func height_at(pos: Vector2) -> float: return source.height_at(pos)
