class_name CombatMapAreaQueriesAdapter
extends CombatMapAreaQueriesPort
var source: CombatMapQueries
func _init(value: CombatMapQueries) -> void: source = value
func is_enemy_in_zones(zones: Array) -> bool: return source.is_enemy_in_zones(zones)
func is_player_in_zones(zones: Array) -> bool: return source.is_player_in_zones(zones)
func segment_hits_enemy(from: Vector2, to: Vector2) -> bool: return source.segment_hits_enemy(from, to)
func is_enemy_in_cone(origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool: return source.is_enemy_in_cone(origin, direction, cone_range, half_angle_deg)
func is_enemy_in_area_circle(center: Vector2, radius: float) -> bool: return source.is_enemy_in_area_circle(center, radius)
func is_player_in_area_circle(center: Vector2, radius: float) -> bool: return source.is_player_in_area_circle(center, radius)
func is_enemy_in_circle(center: Vector2, radius: float) -> bool: return source.is_enemy_in_circle(center, radius)
func is_player_in_circle(center: Vector2, radius: float) -> bool: return source.is_player_in_circle(center, radius)
