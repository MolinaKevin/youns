class_name CombatMapTreeMovementAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func climb_tree(tree: Dictionary, landing: Vector2) -> void: source.climb_tree(tree, landing)
func drop_from_tree(landing: Vector2) -> bool: return source.drop_from_tree(landing)
func fell_tree(tree: Dictionary, direction: Vector2) -> Dictionary: return source.fell_tree(tree, direction)
