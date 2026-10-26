class_name CombatTerrain
extends RefCounted

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

## Geometría lógica del tablero. Recibe los obstáculos declarados por el bioma
## y responde elevación, rampas, altura y ocupación para el combate.
const PATH_CELL := 0.5
const PLATFORM_HEIGHT := 1.5
const RAMP_DEPTH := 1.5
const WARM_CELLS_PER_FRAME := 1500

var world_width := 30.0
var world_height := 30.0
var obstacles: Array[Dictionary] = []
var _blocked_cache: Dictionary = {}
var _height_cache := PackedFloat32Array()
var _warm_next := 0

func configure(width: float, height: float) -> void:
	world_width = width
	world_height = height

func clear() -> void:
	obstacles.clear()
	invalidate()

func add(obstacle: Dictionary) -> void:
	assert(CombatObstacle.is_known(obstacle), "Tipo de obstáculo desconocido: %s" % CombatObstacle.type_of(obstacle))
	obstacles.append(obstacle)
	invalidate()

func invalidate() -> void:
	_blocked_cache.clear()
	_height_cache.clear()
	_warm_next = 0

func elevation_at(pos: Vector2) -> int:
	for obstacle in obstacles:
		if CombatObstacle.type_of(obstacle) != CombatObstacle.PLATFORM:
			continue
		var center: Vector2 = obstacle["pos"]
		var half: Vector2 = obstacle["box"] * 0.5
		if abs(pos.x - center.x) <= half.x and abs(pos.y - center.y) <= half.y:
			return 1
		if pos_in_ramp(pos, obstacle):
			return 1
	return 0

func height_at(pos: Vector2) -> float:
	for obstacle in obstacles:
		if CombatObstacle.type_of(obstacle) != CombatObstacle.PLATFORM:
			continue
		var center: Vector2 = obstacle["pos"]
		var half: Vector2 = obstacle["box"] * 0.5
		if abs(pos.x - center.x) <= half.x and abs(pos.y - center.y) <= half.y:
			return PLATFORM_HEIGHT
		for ramp in obstacle.get("ramps", []):
			var width: float = ramp.get("width", 2.0) * 0.5
			match ramp["side"]:
				"south":
					if abs(pos.x - center.x) < width and pos.y > center.y + half.y and pos.y <= center.y + half.y + RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - (pos.y - (center.y + half.y)) / RAMP_DEPTH)
				"north":
					if abs(pos.x - center.x) < width and pos.y < center.y - half.y and pos.y >= center.y - half.y - RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - ((center.y - half.y) - pos.y) / RAMP_DEPTH)
				"east":
					if abs(pos.y - center.y) < width and pos.x > center.x + half.x and pos.x <= center.x + half.x + RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - (pos.x - (center.x + half.x)) / RAMP_DEPTH)
				"west":
					if abs(pos.y - center.y) < width and pos.x < center.x - half.x and pos.x >= center.x - half.x - RAMP_DEPTH:
						return PLATFORM_HEIGHT * (1.0 - ((center.x - half.x) - pos.x) / RAMP_DEPTH)
	return 0.0

func pos_in_ramp(pos: Vector2, obstacle: Dictionary) -> bool:
	var center: Vector2 = obstacle["pos"]
	var half: Vector2 = obstacle["box"] * 0.5
	for ramp in obstacle.get("ramps", []):
		var width: float = ramp.get("width", 2.0) * 0.5
		match ramp["side"]:
			"north": if abs(pos.x - center.x) < width and pos.y < center.y - half.y and pos.y >= center.y - half.y - RAMP_DEPTH: return true
			"south": if abs(pos.x - center.x) < width and pos.y > center.y + half.y and pos.y <= center.y + half.y + RAMP_DEPTH: return true
			"west": if abs(pos.y - center.y) < width and pos.x < center.x - half.x and pos.x >= center.x - half.x - RAMP_DEPTH: return true
			"east": if abs(pos.y - center.y) < width and pos.x > center.x + half.x and pos.x <= center.x + half.x + RAMP_DEPTH: return true
	return false

func pos_in_ramp_exit(pos: Vector2, obstacle: Dictionary) -> bool:
	const EXIT := 0.6
	var center: Vector2 = obstacle["pos"]
	var half: Vector2 = obstacle["box"] * 0.5
	for ramp in obstacle.get("ramps", []):
		var width: float = ramp.get("width", 2.0) * 0.5
		match ramp["side"]:
			"north": if abs(pos.x - center.x) < width and pos.y < center.y - half.y - RAMP_DEPTH and pos.y >= center.y - half.y - RAMP_DEPTH - EXIT: return true
			"south": if abs(pos.x - center.x) < width and pos.y > center.y + half.y + RAMP_DEPTH and pos.y <= center.y + half.y + RAMP_DEPTH + EXIT: return true
			"west": if abs(pos.y - center.y) < width and pos.x < center.x - half.x - RAMP_DEPTH and pos.x >= center.x - half.x - RAMP_DEPTH - EXIT: return true
			"east": if abs(pos.y - center.y) < width and pos.x > center.x + half.x + RAMP_DEPTH and pos.x <= center.x + half.x + RAMP_DEPTH + EXIT: return true
	return false

func tile_in_obstacle(pos: Vector2, elevation: int = 0) -> bool:
	for obstacle in obstacles:
		var obstacle_type := CombatObstacle.type_of(obstacle)
		if obstacle_type == CombatObstacle.BRIDGE:
			continue
		if obstacle_type == CombatObstacle.PLATFORM:
			if elevation > 0:
				continue
			var center: Vector2 = obstacle["pos"]
			var half: Vector2 = obstacle["box"] * 0.5
			if abs(pos.x - center.x) < half.x and abs(pos.y - center.y) < half.y:
				return true
			continue
		if obstacle.has("box"):
			var half: Vector2 = obstacle["box"] * 0.5
			var center: Vector2 = obstacle["pos"]
			if abs(pos.x - center.x) < half.x and abs(pos.y - center.y) < half.y:
				return true
		elif pos.distance_to(obstacle["pos"]) < obstacle["radius"]:
			return true
	return false

func pos_blocked(pos: Vector2, elevation: int = 0, margin: float = PATH_CELL * 0.5) -> bool:
	if elevation > 0:
		for obstacle in obstacles:
			if CombatObstacle.type_of(obstacle) != CombatObstacle.PLATFORM:
				continue
			var center: Vector2 = obstacle["pos"]
			var half: Vector2 = obstacle["box"] * 0.5
			var in_footprint: bool = abs(pos.x - center.x) <= half.x + PATH_CELL * 0.5 and abs(pos.y - center.y) <= half.y + PATH_CELL * 0.5
			if in_footprint or pos_in_ramp(pos, obstacle) or pos_in_ramp_exit(pos, obstacle):
				return false
		return true
	for obstacle in obstacles:
		var obstacle_type := CombatObstacle.type_of(obstacle)
		if obstacle_type == CombatObstacle.BRIDGE:
			continue
		if obstacle_type == CombatObstacle.PLATFORM:
			var center: Vector2 = obstacle["pos"]
			var half: Vector2 = obstacle["box"] * 0.5 + Vector2(margin, margin)
			if abs(pos.x - center.x) < half.x and abs(pos.y - center.y) < half.y:
				return true
			continue
		if obstacle.has("box"):
			var half: Vector2 = obstacle["box"] * 0.5 + Vector2(margin, margin)
			var center: Vector2 = obstacle["pos"]
			if abs(pos.x - center.x) < half.x and abs(pos.y - center.y) < half.y:
				return true
		elif pos.distance_to(obstacle["pos"]) < obstacle["radius"] + margin:
			return true
	return false

func player_height_at(pos: Vector2, elevation: int) -> float:
	if elevation <= 0:
		return 0.0
	for obstacle in obstacles:
		if CombatObstacle.type_of(obstacle) != CombatObstacle.PLATFORM:
			continue
		var center: Vector2 = obstacle["pos"]
		var half: Vector2 = obstacle["box"] * 0.5
		if abs(pos.x - center.x) <= half.x and abs(pos.y - center.y) <= half.y:
			return PLATFORM_HEIGHT
	return 0.0

func warm_caches(first_radius: float, second_radius: float) -> void:
	if _warm_next < 0:
		return
	var cols := CombatGrid.steps_for(world_width) + 1
	var total := cols * (CombatGrid.steps_for(world_height) + 1)
	var end := mini(_warm_next + WARM_CELLS_PER_FRAME, total)
	for i in range(_warm_next, end):
		@warning_ignore("integer_division")
		var cell := Vector2i(i % cols, i / cols)
		var world := CombatGrid.to_world(cell)
		cell_height(cell, world)
		cell_blocked(cell, world, 0, first_radius)
		cell_blocked(cell, world, 0, second_radius)
	_warm_next = end if end < total else -1

func cell_height(cell: Vector2i, world: Vector2) -> float:
	var cols := CombatGrid.steps_for(world_width) + 1
	var rows := CombatGrid.steps_for(world_height) + 1
	if _height_cache.is_empty():
		_height_cache.resize(cols * rows)
		_height_cache.fill(NAN)
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return height_at(world)
	var index := cell.y * cols + cell.x
	if is_nan(_height_cache[index]):
		_height_cache[index] = height_at(world)
	return _height_cache[index]

func cell_blocked(cell: Vector2i, world: Vector2, elevation: int, margin: float) -> bool:
	var by_margin: Dictionary = _blocked_cache.get_or_add(margin, {})
	var key := Vector3i(cell.x, cell.y, elevation)
	if not by_margin.has(key):
		by_margin[key] = pos_blocked(world, elevation, margin)
	return by_margin[key]
