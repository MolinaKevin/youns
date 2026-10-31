class_name CombatMapMovement
extends "res://features/combat/scene/combat_map_movement_port.gd"

const CombatMovePlanScript := preload("res://features/combat/scene/combat_move_plan.gd")

## Coordina las rutas de navegación con el estado lógico y los waypoints de
## los actores. CombatNavigation calcula caminos; CombatActorMover los anima.
var map: CombatMapArea

func try_move_player_to(pos: Vector2) -> bool:
	var goal := CombatGrid.to_cell(pos)
	var path: Array[Vector2i] = map.terrain.navigation.path_for_move(pos)
	if path.size() < 2:
		return false
	var from_elevation: int = map.player_elevation
	map.player_pos = CombatGrid.to_world(goal)
	map.player_elevation = map.terrain.geometry.bounds.elevation_at(map.player_pos)
	map.actors.movement.clear_player_waypoints()
	for cell in CombatGrid.corners(path).slice(1):
		var world := CombatGrid.to_world(cell)
		var height: float = map.terrain.geometry.bounds.player_height_at(world, maxi(from_elevation, map.terrain.geometry.bounds.elevation_at(world)))
		map.actors.movement.add_player_waypoint(Vector3(world.x, height, world.y))
	map.terrain.navigation.clear_planned_path()
	map.selection.targeting.modes.clear_move_selection()
	map.actors.state.targets.sync_targets()
	if map.actors.movement.has_player_waypoints():
		map.actors.movement.set_player_final_waypoint(map.actors.state.targets.player_target())
	return true

func plan_player_move(pos: Vector2) -> String:
	return map.terrain.navigation.plan_move(pos, map.player_elevation, map.actors.state.geometry.player_radius(), map.enemy_pos, map.actors.state.geometry.enemy_radius())

func path_cost() -> float:
	return map.terrain.navigation.planned_path_cost()

func move_enemy_toward(target: Vector2, move_range: float) -> bool:
	var route: Dictionary = map.terrain.navigation.find_toward(map.enemy_pos, target, move_range, map.enemy_elevation,
		map.actors.state.geometry.enemy_radius(), map.player_pos, map.actors.state.geometry.player_radius())
	var plan := CombatMovePlanScript.parse(route)
	if plan == null:
		return false
	map.actors.movement.clear_enemy_waypoints()
	for cell in CombatGrid.corners(plan.path).slice(1):
		var world := CombatGrid.to_world(cell)
		map.actors.movement.add_enemy_waypoint(Vector3(world.x, map.terrain.geometry.bounds.elevation_height(map.terrain.geometry.bounds.elevation_at(world)), world.y))
	map.enemy_pos = plan.destination
	map.enemy_elevation = map.terrain.geometry.bounds.elevation_at(map.enemy_pos)
	map.actors.state.targets.sync_targets()
	return true
