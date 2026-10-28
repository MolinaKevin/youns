class_name CombatMapRockPort
extends RefCounted

func rocks_in_range(_origin: Vector2, _reach: float) -> Array[Dictionary]: return []
func rock_near(_pos: Vector2) -> Dictionary: return {}
func can_jump_land_at(_pos: Vector2) -> bool: return false
func land_player_from_jump(_pos: Vector2) -> void: pass
func is_enemy_near(_pos: Vector2, _radius: float) -> bool: return false
func can_blink_to(_pos: Vector2) -> bool: return false
