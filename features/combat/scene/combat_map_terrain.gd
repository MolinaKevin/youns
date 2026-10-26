class_name CombatMapTerrain
extends RefCounted

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

## Fachada de consultas espaciales para sistemas de combate. Mantiene juntos
## terreno, navegación y geometría sin exponer su estructura interna.
var map: MapArea
var logic: CombatTerrain
var navigation: CombatNavigation

## Colección lógica de obstáculos. Los sistemas que cambian el tablero la usan
## a través de esta fachada; CombatTerrain conserva la lista y sus cachés.
func obstacles() -> Array[Dictionary]:
	return logic.obstacles

## Copia superficial para iterar mientras se pueden eliminar obstáculos.
func obstacle_snapshot() -> Array[Dictionary]:
	return logic.obstacles.duplicate()

func add_obstacle(obstacle: Dictionary) -> void:
	logic.add(obstacle)

func remove_obstacle(obstacle: Dictionary) -> void:
	logic.obstacles.erase(obstacle)
	logic.invalidate()

func is_inside_bounds(pos: Vector2, margin: float = 0.0) -> bool:
	return pos.x >= margin and pos.y >= margin \
		and pos.x <= logic.world_width - margin and pos.y <= logic.world_height - margin

func clamp_to_bounds(pos: Vector2, margin: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, margin, logic.world_width - margin),
		clampf(pos.y, margin, logic.world_height - margin),
	)

func platforms() -> Array[Dictionary]:
	return logic.obstacles.filter(func(obstacle): return CombatObstacle.type_of(obstacle) == CombatObstacle.PLATFORM)

## Hasta qué fracción del segmento puede recorrer un cuerpo de radio `margin`
## sin abandonar el tablero.
func bounds_travel_fraction(from: Vector2, to: Vector2, margin: float) -> float:
	var fraction := 1.0
	var direction := to - from
	for axis in 2:
		if absf(direction[axis]) < 0.0001:
			continue
		var size: float = logic.world_width if axis == 0 else logic.world_height
		var limit: float = size - margin if direction[axis] > 0.0 else margin
		fraction = minf(fraction, maxf(0.0, (limit - from[axis]) / direction[axis]))
	return fraction

func elevation_at(pos: Vector2) -> int:
	return logic.elevation_at(pos)

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	return map.queries.has_line_of_sight(from, to)

func movement_distance(from: Vector2, to: Vector2) -> float:
	return map.queries.movement_distance(from, to)

func reachable_cells(from: Vector2, move_range: float, elevation: int, actor_radius: float, blocked_by: Vector2, blocked_radius: float) -> Array[Vector2i]:
	return navigation.begin_move(from, move_range, elevation, actor_radius, blocked_by, blocked_radius)

func plan_move(pos: Vector2, elevation: int, actor_radius: float, blocked_by: Vector2, blocked_radius: float) -> String:
	return navigation.plan_move(pos, elevation, actor_radius, blocked_by, blocked_radius)

func path_for_move(pos: Vector2) -> Array[Vector2i]:
	return navigation.path_for_move(pos)

func clear_planned_path() -> void:
	navigation.clear_planned_path()

func planned_path() -> Array[Vector2]:
	return navigation.last_path

func planned_path_cost() -> float:
	return navigation.last_path_cost

func find_toward(from: Vector2, target: Vector2, move_range: float, elevation: int, actor_radius: float, blocked_by: Vector2, blocked_radius: float) -> Dictionary:
	return navigation.find_toward(from, target, move_range, elevation, actor_radius, blocked_by, blocked_radius)

func player_height_at(pos: Vector2, elevation: int) -> float:
	return logic.player_height_at(pos, elevation)

func elevation_height(elevation: int) -> float:
	return float(elevation) * CombatTerrain.PLATFORM_HEIGHT

func warm_caches(first_radius: float, second_radius: float) -> void:
	logic.warm_caches(first_radius, second_radius)

func player_contact_radius() -> float:
	return map.player_area_contact_radius()

func enemy_contact_radius() -> float:
	return map.enemy_area_contact_radius()

func clip_path_at_obstacle(from: Vector2, to: Vector2) -> Vector2:
	return map.clip_path_at_obstacle(from, to)

func is_blocked(pos: Vector2, elevation: int = 0, margin: float = CombatTerrain.PATH_CELL * 0.5) -> bool:
	return logic.pos_blocked(pos, elevation, margin)

func is_tile_obstructed(pos: Vector2, elevation: int = 0) -> bool:
	return logic.tile_in_obstacle(pos, elevation)

func can_blink_to(pos: Vector2) -> bool:
	if not is_inside_bounds(pos):
		return false
	if pos.distance_to(map.enemy_pos) < map.MIN_SEPARATION:
		return false
	return not is_blocked(pos, elevation_at(pos), map.actors.player_radius())
