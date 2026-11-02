class_name CombatEnemyBoardEffectsAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func trigger_enemy_traps() -> int: return source.trigger_enemy_traps()
func puddle_effects_along(from: Vector2, to: Vector2, margin: float) -> Dictionary: return source.puddle_effects_along(from, to, margin)
func puddle_damage_along(from: Vector2, to: Vector2, margin: float) -> Dictionary: return source.puddle_damage_along(from, to, margin)
func crosses_player_overwatch(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, reach: float, angle: float) -> bool: return source.crosses_player_overwatch(from, to, origin, direction, reach, angle)
func clear_player_overwatch() -> void: source.clear_player_overwatch()
