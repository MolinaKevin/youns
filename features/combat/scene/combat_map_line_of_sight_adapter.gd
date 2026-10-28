class_name CombatMapLineOfSightAdapter
extends CombatMapLineOfSightPort
var source: CombatMapQueries
func _init(value: CombatMapQueries) -> void: source = value
func has_line_of_sight(from: Vector2, to: Vector2) -> bool: return source.has_line_of_sight(from, to)
func line_of_sight_clear(from: Vector2, to: Vector2, block_rocks: bool, block_bridges: bool, from_elevation: int, to_elevation: int) -> bool: return source.line_of_sight_clear(from, to, block_rocks, block_bridges, from_elevation, to_elevation)
