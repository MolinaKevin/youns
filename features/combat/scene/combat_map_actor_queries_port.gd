class_name CombatMapActorQueriesPort
extends RefCounted
func movement_distance(_from: Vector2, _to: Vector2) -> float: return 0.0
func actors_gap() -> float: return 0.0
func is_enemy_in_attack_range(_attack_range: float) -> bool: return false
func is_enemy_in_melee_range() -> bool: return false
func is_player_in_melee_range() -> bool: return false
func player_area_contact_radius() -> float: return 0.0
func enemy_area_contact_radius() -> float: return 0.0
