class_name CombatMapPuddleMutationPort
extends RefCounted

func move_puddle(zone: Dictionary, _to: Vector2) -> Dictionary: return zone
func convert_puddles(_center: Vector2, _radius: float, _from_effects: Array, _to_effect: String) -> int: return 0
func tick_puddles() -> void: pass
