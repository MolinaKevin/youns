class_name CombatEnemyBoardStateAdapter
extends CombatEnemyBoardStatePort
var source
func _init(value) -> void: source = value
func player_position() -> Vector2: return source.player_position()
func enemy_position() -> Vector2: return source.enemy_position()
func world_center() -> Vector2: return source.world_center()
func clamp_to_world(pos: Vector2) -> Vector2: return source.clamp_to_world(pos)
