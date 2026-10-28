class_name CombatMapAreaQueriesPort
extends RefCounted
func is_enemy_in_zones(_zones: Array) -> bool: return false
func is_player_in_zones(_zones: Array) -> bool: return false
func segment_hits_enemy(_from: Vector2, _to: Vector2) -> bool: return false
func is_enemy_in_cone(_origin: Vector2, _direction: Vector2, _cone_range: float, _half_angle_deg: float) -> bool: return false
func is_enemy_in_area_circle(_center: Vector2, _radius: float) -> bool: return false
func is_player_in_area_circle(_center: Vector2, _radius: float) -> bool: return false
func is_enemy_in_circle(_center: Vector2, _radius: float) -> bool: return false
func is_player_in_circle(_center: Vector2, _radius: float) -> bool: return false
