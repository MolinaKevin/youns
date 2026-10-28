class_name CombatMapTreeQueriesPort
extends RefCounted

func tree_at(_pos: Vector2) -> Dictionary: return {}
func can_drop_at(_pos: Vector2) -> bool: return false
func is_tree_burning(_tree: Dictionary) -> bool: return false
func is_tree_near(_pos: Vector2, _reach: float) -> bool: return false
func first_tree_on_segment(_from: Vector2, _to: Vector2) -> Dictionary: return {}
func is_player_in_tree(_tree: Dictionary) -> bool: return false
func player_is_in_tree() -> bool: return false
