class_name CombatEnemyBoardEffectsPort
extends RefCounted

func trigger_enemy_traps() -> int: return 0
func puddle_effects_along(_from: Vector2, _to: Vector2, _contact_margin: float) -> Dictionary: return {}
func puddle_damage_along(_from: Vector2, _to: Vector2, _contact_margin: float) -> Dictionary: return {}
func crosses_player_overwatch(_from: Vector2, _to: Vector2, _origin: Vector2, _direction: Vector2, _range: float, _half_angle: float) -> bool: return false
func clear_player_overwatch() -> void: pass
