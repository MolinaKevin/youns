class_name CombatNavigation
extends RefCounted

## Estado y algoritmos de navegación del tablero. Depende sólo del terreno y
## de los límites configurados; no conoce MapArea ni guarda estado de actores.
const PATH_SLACK := 1.0824

var terrain: CombatTerrain
var world_width := 30.0
var world_height := 30.0
var move_reach: Dictionary = {}
var move_origin := Vector2.ZERO
var move_range := 0.0
var last_path: Array[Vector2] = []
var last_path_cost := 0.0

func configure(p_terrain: CombatTerrain, width: float, height: float) -> void:
	terrain = p_terrain
	world_width = width
	world_height = height

func begin_move(from_pos: Vector2, max_range: float, elevation: int, radius: float, other_pos: Vector2, other_radius: float) -> Array[Vector2i]:
	move_origin = from_pos
	move_range = max_range
	move_reach = _grid_reach(from_pos, max_range, elevation, radius, other_pos, other_radius)
	var visible_cells: Array[Vector2i] = []
	for cell: Vector2i in move_reach:
		if _in_move_circle(cell, move_origin, move_range):
			visible_cells.append(cell)
	return visible_cells

func plan_move(pos: Vector2, elevation: int, radius: float, other_pos: Vector2, other_radius: float) -> String:
	var goal := CombatGrid.to_cell(pos)
	if not move_reach.has(goal) or not _in_move_circle(goal, move_origin, move_range):
		last_path = []
		last_path_cost = INF
		if not _in_move_circle(goal, move_origin, move_range):
			return "range"
		if not _grid_passable(goal, elevation, radius, other_pos, other_radius):
			return "blocked"
		return "no_path"
	var path := CombatGrid.path_to(move_reach, goal)
	last_path.clear()
	for cell in CombatGrid.corners(path):
		last_path.append(CombatGrid.to_world(cell))
	var start := CombatGrid.to_cell(move_origin)
	var direct := CombatGrid.octile(goal - start)
	var scale := 1.0
	if direct > 0.0:
		scale = (CombatGrid.to_world(goal).distance_to(CombatGrid.to_world(start)) / CombatGrid.CELL) / direct
	last_path_cost = float(move_reach[goal]["cost"]) * scale * CombatGrid.CELL
	return ""

func path_for_move(pos: Vector2) -> Array[Vector2i]:
	var goal := CombatGrid.to_cell(pos)
	if not _in_move_circle(goal, move_origin, move_range):
		return []
	return CombatGrid.path_to(move_reach, goal)

func clear_planned_path() -> void:
	last_path = []
	last_path_cost = 0.0

func find_toward(from_pos: Vector2, target: Vector2, max_range: float, elevation: int, radius: float, other_pos: Vector2, other_radius: float) -> Dictionary:
	if from_pos.distance_to(target) < 0.01:
		return {}
	var reach := _grid_reach(from_pos, max_range, elevation, radius, other_pos, other_radius)
	var start := CombatGrid.to_cell(from_pos)
	var best := start
	var best_distance := from_pos.distance_to(target)
	var best_cost := 0.0
	for cell: Vector2i in reach:
		if not _in_move_circle(cell, from_pos, max_range):
			continue
		var distance := CombatGrid.to_world(cell).distance_to(target)
		var cost: float = reach[cell]["cost"]
		if distance < best_distance - 0.0001 or (absf(distance - best_distance) <= 0.0001 and cost < best_cost):
			best = cell
			best_distance = distance
			best_cost = cost
	if best == start:
		return {}
	return {"destination": CombatGrid.to_world(best), "path": CombatGrid.path_to(reach, best)}

func _grid_reach(from_pos: Vector2, max_range: float, elevation: int, radius: float, other_pos: Vector2, other_radius: float) -> Dictionary:
	var start := CombatGrid.to_cell(from_pos)
	var escape_separation := -1.0
	if not _grid_passable(start, elevation, radius, other_pos, other_radius):
		escape_separation = minf(radius + other_radius, CombatGrid.to_world(start).distance_to(other_pos))
	return CombatGrid.reachable(start, CombatGrid.steps_for(max_range * PATH_SLACK), func(cell: Vector2i) -> bool: return _grid_passable(cell, elevation, radius, other_pos, other_radius, escape_separation))

func _in_move_circle(cell: Vector2i, origin: Vector2, max_range: float) -> bool:
	return CombatGrid.to_world(cell).distance_to(origin) <= max_range + CombatGrid.CELL * 0.5

func _grid_passable(cell: Vector2i, elevation: int, radius: float, other_pos: Vector2, other_radius: float, escape_separation: float = -1.0) -> bool:
	var world_pos := CombatGrid.to_world(cell)
	if world_pos.x < 0.0 or world_pos.x > world_width or world_pos.y < 0.0 or world_pos.y > world_height:
		return false
	var escaping := escape_separation >= 0.0
	if terrain.cell_blocked(cell, world_pos, elevation, 0.0 if escaping else radius):
		return false
	var minimum_separation := escape_separation if escaping else radius + other_radius
	return world_pos.distance_to(other_pos) >= minimum_separation - 0.0001
