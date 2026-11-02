class_name CombatMapTerrainSpatialAdapter
extends RefCounted

var source: CombatMapTerrain
func _init(value: CombatMapTerrain = null) -> void: source = value
func has_line_of_sight(from: Vector2, to: Vector2) -> bool: return source.has_line_of_sight(from, to)
func movement_distance(from: Vector2, to: Vector2) -> float: return source.movement_distance(from, to)
func player_contact_radius() -> float: return source.player_contact_radius()
func enemy_contact_radius() -> float: return source.enemy_contact_radius()
