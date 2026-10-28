class_name CombatBoardFixture
extends RefCounted

const MapAreaScript := preload("res://features/combat/scene/map_area.gd")

static func empty_modules_map() -> MapArea:
	var map = MapAreaScript.new()
	map.solid_obstacles.clear()
	map.player_pos = Vector2(2, 15)
	map.enemy_pos = Vector2(28, 15)
	return map
