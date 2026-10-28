class_name CombatMapTargetQueriesPort
extends RefCounted
func is_click_on_enemy(_pos: Vector2) -> bool: return false
func is_click_on_player(_pos: Vector2) -> bool: return false
func is_enemy_in_card_pattern(_pattern: CardPattern, _origin: Vector2, _direction: Vector2, _primary: float) -> bool: return false
