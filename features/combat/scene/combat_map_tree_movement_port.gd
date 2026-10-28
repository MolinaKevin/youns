class_name CombatMapTreeMovementPort
extends RefCounted

func climb_tree(_tree: Dictionary, _landing: Vector2) -> void: pass
func drop_from_tree(_landing: Vector2) -> bool: return false
func fell_tree(tree: Dictionary, _direction: Vector2) -> Dictionary: return tree
