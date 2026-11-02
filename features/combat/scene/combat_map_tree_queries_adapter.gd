class_name CombatMapTreeQueriesAdapter
extends RefCounted
var source
func _init(value = null) -> void: source = value
func tree_at(pos: Vector2) -> Dictionary: return source.tree_at(pos)
func can_drop_at(pos: Vector2) -> bool: return source.can_drop_at(pos)
func is_tree_burning(tree: Dictionary) -> bool: return source.is_tree_burning(tree)
func is_tree_near(pos: Vector2, reach: float) -> bool: return source.is_tree_near(pos, reach)
func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary: return source.first_tree_on_segment(from, to)
func is_player_in_tree(tree: Dictionary) -> bool: return source.is_player_in_tree(tree)
func player_is_in_tree() -> bool: return source.player_is_in_tree()
