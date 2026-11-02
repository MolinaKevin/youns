class_name CombatMapTargetQueriesAdapter
extends RefCounted
var source
func _init(value) -> void: source = value
func is_click_on_enemy(pos: Vector2) -> bool: return source.is_click_on_enemy(pos)
func is_click_on_player(pos: Vector2) -> bool: return source.is_click_on_player(pos)
func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool: return source.is_enemy_in_card_pattern(pattern, origin, direction, primary)
