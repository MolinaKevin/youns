class_name CombatMapTerrainNavigation
extends "res://features/combat/scene/combat_map_terrain_navigation_port.gd"

var terrain: CombatMapTerrain

func _init(owner: CombatMapTerrain = null) -> void:
	terrain = owner

func reachable_cells(from: Vector2, move_range: float, elevation: int, actor_radius: float, blocked_by: Vector2, blocked_radius: float) -> Array[Vector2i]:
	return terrain.reachable_cells(from, move_range, elevation, actor_radius, blocked_by, blocked_radius)

func plan_move(pos: Vector2, elevation: int, actor_radius: float, blocked_by: Vector2, blocked_radius: float) -> String:
	return terrain.plan_move(pos, elevation, actor_radius, blocked_by, blocked_radius)

func path_for_move(pos: Vector2) -> Array[Vector2i]:
	return terrain.path_for_move(pos)

func clear_planned_path() -> void:
	terrain.clear_planned_path()

func planned_path() -> Array[Vector2]:
	return terrain.planned_path()

func planned_path_cost() -> float:
	return terrain.planned_path_cost()

func find_toward(from: Vector2, target: Vector2, move_range: float, elevation: int, actor_radius: float, blocked_by: Vector2, blocked_radius: float) -> Dictionary:
	return terrain.find_toward(from, target, move_range, elevation, actor_radius, blocked_by, blocked_radius)
