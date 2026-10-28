class_name CombatMapGrenadePlacementPort
extends RefCounted
func grenade_landing(from: Vector2, _target: Vector2, _bounce: float) -> Vector2: return from
func show_grenade_preview(_landing: Vector2, _radius: float) -> void: pass
func clear_grenade_preview() -> void: pass
func is_enemy_in_explosion(_center: Vector2, _radius: float) -> bool: return false
