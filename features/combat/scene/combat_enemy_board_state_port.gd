class_name CombatEnemyBoardStatePort
extends RefCounted

func player_position() -> Vector2: return Vector2.ZERO
func enemy_position() -> Vector2: return Vector2.ZERO
func world_center() -> Vector2: return Vector2.ZERO
func clamp_to_world(pos: Vector2) -> Vector2: return pos
