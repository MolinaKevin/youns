class_name CombatMapRockAdapter
extends RefCounted

var source: CombatMapObstacleAdapter

func _init(value: CombatMapObstacleAdapter = null) -> void: source = value
func rocks_in_range(origin: Vector2, reach: float) -> Array[Dictionary]: return source.rocks_in_range(origin, reach)
func rock_near(pos: Vector2) -> Dictionary: return source.rock_near(pos)
func can_jump_land_at(pos: Vector2) -> bool: return source.can_jump_land_at(pos)
func land_player_from_jump(pos: Vector2) -> void: source.land_player_from_jump(pos)
func is_enemy_near(pos: Vector2, radius: float) -> bool: return source.is_enemy_near(pos, radius)
func can_blink_to(pos: Vector2) -> bool: return source.can_blink_to(pos)
