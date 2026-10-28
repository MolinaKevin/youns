class_name CombatMapTreeEffectsPort
extends RefCounted

func ignite_trees_in_circle(_center: Vector2, _radius: float) -> int: return 0
func ignite_trees_in_cone(_origin: Vector2, _direction: Vector2, _reach: float, _half_angle: float) -> int: return 0
func extinguish_trees_in_circle(_center: Vector2, _radius: float) -> int: return 0
func tick_trees() -> void: pass
