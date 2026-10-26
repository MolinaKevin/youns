class_name CombatMapMovement
extends RefCounted

## Coordina las rutas de navegación con el estado lógico y los waypoints de
## los actores. CombatNavigation calcula caminos; CombatActorMover los anima.
var map: MapArea

func try_move_player_to(pos: Vector2) -> bool:
	var goal := CombatGrid.to_cell(pos)
	var path: Array[Vector2i] = map.terrain.path_for_move(pos)
	if path.size() < 2:
		return false
	var from_elevation: int = map.player_elevation
	map.player_pos = CombatGrid.to_world(goal)
	map.player_elevation = map.terrain.elevation_at(map.player_pos)
	map.actors.clear_player_waypoints()
	for cell in CombatGrid.corners(path).slice(1):
		var world := CombatGrid.to_world(cell)
		var height: float = map.terrain.player_height_at(world, maxi(from_elevation, map.terrain.elevation_at(world)))
		map.actors.add_player_waypoint(Vector3(world.x, height, world.y))
	map.terrain.clear_planned_path()
	map.interactions.clear_move_selection()
	map.update_actor_positions()
	if map.actors.has_player_waypoints():
		map.actors.set_player_final_waypoint(map.actors.player_target())
	return true

func plan_player_move(pos: Vector2) -> String:
	return map.terrain.plan_move(pos, map.player_elevation, map.actors.player_radius(), map.enemy_pos, map.actors.enemy_radius())

func path_cost() -> float:
	return map.terrain.planned_path_cost()

func move_enemy_toward(target: Vector2, move_range: float) -> bool:
	var route: Dictionary = map.terrain.find_toward(map.enemy_pos, target, move_range, map.enemy_elevation,
		map.actors.enemy_radius(), map.player_pos, map.actors.player_radius())
	if route.is_empty():
		return false
	map.actors.clear_enemy_waypoints()
	for cell in CombatGrid.corners(route["path"]).slice(1):
		var world := CombatGrid.to_world(cell)
		map.actors.add_enemy_waypoint(Vector3(world.x, map.terrain.elevation_height(map.terrain.elevation_at(world)), world.y))
	map.enemy_pos = route["destination"]
	map.enemy_elevation = map.terrain.elevation_at(map.enemy_pos)
	map.update_actor_positions()
	return true
