class_name CombatEnemyBoardQueriesAdapter
extends CombatEnemyBoardQueriesPort
var source
func _init(value) -> void: source = value
func has_line_of_sight(from: Vector2, to: Vector2) -> bool: return source.has_line_of_sight(from, to)
func movement_distance(from: Vector2, to: Vector2) -> float: return source.movement_distance(from, to)
func actors_gap() -> float: return source.actors_gap()
func enemy_contact_radius() -> float: return source.enemy_contact_radius()
