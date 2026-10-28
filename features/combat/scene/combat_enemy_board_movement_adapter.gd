class_name CombatEnemyBoardMovementAdapter
extends CombatEnemyBoardMovementPort
var source
func _init(value) -> void: source = value
func move_enemy_toward(target: Vector2, move_range: float) -> bool: return source.move_enemy_toward(target, move_range)
