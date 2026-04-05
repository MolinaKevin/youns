extends Control

signal tile_selected(cell: Vector2i)

var grid_width := 150
var grid_height := 150

var tile_width := 8
var tile_height := 4
var origin := Vector2(500, 80)

var player_pos := Vector2i(132, 135)
var enemy_pos := Vector2i(6, 8)

var player_shape := [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1)
]

var enemy_shape := [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1)
]

var selected_move_range := 0
var selected_attack_range := 0
var move_preview_target := Vector2i(-1, -1)
var move_preview_path: Array[Vector2i] = []
var reachable_cells: Dictionary = {}
var grenade_landing := Vector2i(-1, -1)
var grenade_aoe_radius := 0
var selected_trap_range := 0
var trap_zones: Array = []
var enemy_hp := 35

var obstacle_pos := Vector2i(65, 65)
var obstacle_shape: Array = []

# Obstáculos de cobertura: bloquean movimiento pero no LOS
var cover_obstacles: Array = [
	{"pos": Vector2i(30, 90), "shape": []},
	{"pos": Vector2i(100, 40), "shape": []},
	{"pos": Vector2i(110, 110), "shape": []},
]
var cover_shape_template: Array = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
]

# Obstáculos de niebla: se puede caminar pero bloquean LOS
var fog_obstacles: Array = [
	{"pos": Vector2i(50, 110), "shape": []},
	{"pos": Vector2i(90, 70), "shape": []},
]

func _ready() -> void:
	custom_minimum_size = Vector2(800, 500)
	for y in range(21):
		for x in range(21):
			obstacle_shape.append(Vector2i(x, y))
	for obs in cover_obstacles:
		obs["shape"] = cover_shape_template.duplicate()
	for obs in fog_obstacles:
		obs["shape"] = cover_shape_template.duplicate()
	queue_redraw()

func grid_to_screen(cell: Vector2i) -> Vector2:
	var sx = (cell.x - cell.y) * (tile_width / 2.0)
	var sy = (cell.x + cell.y) * (tile_height / 2.0)
	return origin + Vector2(sx, sy)

func draw_iso_tile(cell: Vector2i, color: Color = Color(0, 0, 0, 0), filled: bool = false) -> void:
	var center = grid_to_screen(cell)

	var top = center + Vector2(0, -tile_height / 2.0)
	var right = center + Vector2(tile_width / 2.0, 0)
	var bottom = center + Vector2(0, tile_height / 2.0)
	var left = center + Vector2(-tile_width / 2.0, 0)

	var points = PackedVector2Array([top, right, bottom, left])

	if filled:
		draw_colored_polygon(points, color)

	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0.35, 0.35, 0.35), 1.0)

func get_occupied_cells(center: Vector2i, shape: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in shape:
		cells.append(center + offset)
	return cells

func draw_unit_footprint(center: Vector2i, shape: Array, color: Color) -> void:
	for cell in get_occupied_cells(center, shape):
		draw_iso_tile(cell, Color(color.r, color.g, color.b, 0.30), true)

func draw_actor(center_cell: Vector2i, color: Color) -> void:
	var center = grid_to_screen(center_cell)
	var rect = Rect2(center.x - 14, center.y - 42, 28, 42)
	draw_rect(rect, color, true)

func movement_distance(a: Vector2i, b: Vector2i) -> float:
	var dx := float(a.x - b.x)
	var dy := float(a.y - b.y)
	return sqrt(dx * dx + dy * dy)
	
func _draw() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var cell = Vector2i(x, y)

			var highlight := false
			if selected_move_range > 0 and reachable_cells.has(cell):
				highlight = true

			var in_attack_range := false
			if selected_attack_range > 0:
				var dist = movement_distance(player_pos, cell)
				if dist <= float(selected_attack_range) and has_line_of_sight(player_pos, cell):
					in_attack_range = true

			var in_trap_range := false
			if selected_trap_range > 0:
				if movement_distance(player_pos, cell) <= float(selected_trap_range):
					in_trap_range = true

			var in_trap_zone := false
			for trap in trap_zones:
				if movement_distance(trap["pos"], cell) <= float(trap["radius"]):
					in_trap_zone = true
					break

			var in_grenade_aoe := false
			if grenade_landing.x >= 0 and grenade_aoe_radius > 0:
				if movement_distance(grenade_landing, cell) <= float(grenade_aoe_radius):
					in_grenade_aoe = true

			if in_trap_zone:
				draw_iso_tile(cell, Color(0.8, 0.1, 0.8, 0.30), true)
			elif in_grenade_aoe:
				draw_iso_tile(cell, Color(0.9, 0.8, 0.1, 0.35), true)
			elif in_trap_range:
				draw_iso_tile(cell, Color(0.9, 0.6, 0.9, 0.20), true)
			elif in_attack_range:
				draw_iso_tile(cell, Color(0.9, 0.4, 0.1, 0.20), true)
			elif highlight:
				draw_iso_tile(cell, Color(0.2, 0.4, 0.8, 0.20), true)
			else:
				draw_iso_tile(cell)

	if move_preview_target.x >= 0:
		if move_preview_path.size() >= 2:
			var points := PackedVector2Array()
			for c in move_preview_path:
				points.append(grid_to_screen(c))
			draw_polyline(points, Color(1.0, 1.0, 1.0, 0.85), 2.0)
		draw_iso_tile(move_preview_target, Color(0.2, 0.9, 0.2, 0.6), true)

	draw_unit_footprint(player_pos, player_shape, Color(0.2, 0.8, 0.2))
	draw_unit_footprint(enemy_pos, enemy_shape, Color(0.8, 0.2, 0.2))
	draw_unit_footprint(obstacle_pos, obstacle_shape, Color(0.4, 0.25, 0.1))
	for obs in cover_obstacles:
		draw_unit_footprint(obs["pos"], obs["shape"], Color(0.3, 0.4, 0.6))
	for obs in fog_obstacles:
		draw_unit_footprint(obs["pos"], obs["shape"], Color(0.6, 0.8, 0.4))

	draw_actor(player_pos, Color(0.2, 0.8, 0.2))
	draw_actor(enemy_pos, Color(0.8, 0.2, 0.2))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = screen_to_grid_approx(event.position)
		if is_inside_grid(cell):
			tile_selected.emit(cell)

func screen_to_grid_approx(pos: Vector2) -> Vector2i:
	var local_pos = pos - origin

	var gx = (local_pos.x / (tile_width / 2.0) + local_pos.y / (tile_height / 2.0)) / 2.0
	var gy = (local_pos.y / (tile_height / 2.0) - local_pos.x / (tile_width / 2.0)) / 2.0

	return Vector2i(roundi(gx), roundi(gy))

func is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_width and cell.y >= 0 and cell.y < grid_height

func can_place_unit(center: Vector2i, shape: Array) -> bool:
	var enemy_cells = get_occupied_cells(enemy_pos, enemy_shape)
	var obstacle_cells = get_occupied_cells(obstacle_pos, obstacle_shape)

	for cell in get_occupied_cells(center, shape):
		if not is_inside_grid(cell):
			return false
		if cell in enemy_cells:
			return false
		if cell in obstacle_cells:
			return false
		for obs in cover_obstacles:
			if cell in get_occupied_cells(obs["pos"], obs["shape"]):
				return false

	return true

func _blocked_cells_set() -> Dictionary:
	var blocked: Dictionary = {}
	for cell in get_occupied_cells(obstacle_pos, obstacle_shape):
		blocked[cell] = true
	for obs in cover_obstacles:
		for cell in get_occupied_cells(obs["pos"], obs["shape"]):
			blocked[cell] = true
	for cell in get_occupied_cells(enemy_pos, enemy_shape):
		blocked[cell] = true
	return blocked

func _dijkstra(start: Vector2i, budget: float) -> Dictionary:
	var dist: Dictionary = {start: 0.0}
	var blocked := _blocked_cells_set()
	# open list entries: [cost, x, y]
	var open_list: Array = [[0.0, start.x, start.y]]
	while not open_list.is_empty():
		open_list.sort()
		var entry: Array = open_list.pop_front()
		var cost: float = entry[0]
		var cell := Vector2i(entry[1], entry[2])
		if cost > dist.get(cell, INF) + 0.001:
			continue
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var next := cell + Vector2i(dx, dy)
				if not is_inside_grid(next):
					continue
				if blocked.has(next):
					continue
				var new_cost: float = cost + sqrt(float(dx * dx + dy * dy))
				if new_cost > budget + 0.001:
					continue
				if new_cost < dist.get(next, INF) - 0.001:
					dist[next] = new_cost
					open_list.append([new_cost, next.x, next.y])
	return dist

func _astar_path(start: Vector2i, goal: Vector2i, budget: float) -> Array[Vector2i]:
	if not reachable_cells.has(goal):
		return []
	var blocked := _blocked_cells_set()
	var open_list: Array = [[0.0, start.x, start.y]]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	while not open_list.is_empty():
		open_list.sort()
		var entry: Array = open_list.pop_front()
		var cell := Vector2i(entry[1], entry[2])
		if cell == goal:
			var path: Array[Vector2i] = []
			var cur := goal
			while cur != start:
				path.push_front(cur)
				cur = came_from[cur]
			path.push_front(start)
			return path
		var g: float = g_score.get(cell, INF)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var next := cell + Vector2i(dx, dy)
				if not is_inside_grid(next):
					continue
				if blocked.has(next) and next != goal:
					continue
				var new_g: float = g + sqrt(float(dx * dx + dy * dy))
				if new_g > budget + 0.001:
					continue
				if new_g < g_score.get(next, INF) - 0.001:
					g_score[next] = new_g
					came_from[next] = cell
					open_list.append([new_g + movement_distance(next, goal), next.x, next.y])
	return []

func get_path_cost(cell: Vector2i) -> float:
	return reachable_cells.get(cell, -1.0)

func show_move_preview(target: Vector2i) -> void:
	move_preview_target = target
	move_preview_path = _astar_path(player_pos, target, float(selected_move_range))
	queue_redraw()

func clear_move_preview() -> void:
	move_preview_target = Vector2i(-1, -1)
	move_preview_path.clear()
	queue_redraw()

func start_move_selection(move_range: int) -> void:
	selected_move_range = move_range
	reachable_cells = _dijkstra(player_pos, float(move_range))
	queue_redraw()

func clear_move_selection() -> void:
	selected_move_range = 0
	reachable_cells.clear()
	queue_redraw()

func start_attack_selection(attack_range: int) -> void:
	selected_attack_range = attack_range
	queue_redraw()

func clear_attack_selection() -> void:
	selected_attack_range = 0
	queue_redraw()

func is_enemy_in_attack_range(attack_range: int) -> bool:
	var enemy_cells = get_occupied_cells(enemy_pos, enemy_shape)
	for e in enemy_cells:
		if movement_distance(player_pos, e) <= float(attack_range) and has_line_of_sight(player_pos, e):
			return true
	return false

func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var obstacle_cells = get_occupied_cells(obstacle_pos, obstacle_shape)
	for obs in fog_obstacles:
		obstacle_cells.append_array(get_occupied_cells(obs["pos"], obs["shape"]))

	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y

	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy

	while x0 != x1 or y0 != y1:
		var current := Vector2i(x0, y0)
		if current != from and current in obstacle_cells:
			return false
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy

	return true

func try_move_player_to(cell: Vector2i, _move_range: int) -> bool:
	if not reachable_cells.has(cell):
		return false
	player_pos = cell
	clear_move_selection()
	queue_redraw()
	return true

func is_enemy_in_melee_range() -> bool:
	var player_cells = get_occupied_cells(player_pos, player_shape)
	var enemy_cells = get_occupied_cells(enemy_pos, enemy_shape)

	for p in player_cells:
		for e in enemy_cells:
			var dist = abs(p.x - e.x) + abs(p.y - e.y)
			if dist == 1:
				return true

	return false

func set_enemy_hp(hp: int) -> void:
	enemy_hp = hp
	queue_redraw()

func can_place_enemy(center: Vector2i) -> bool:
	var player_cells = get_occupied_cells(player_pos, player_shape)
	var obstacle_cells = get_occupied_cells(obstacle_pos, obstacle_shape)
	for cell in get_occupied_cells(center, enemy_shape):
		if not is_inside_grid(cell):
			return false
		if cell in player_cells:
			return false
		if cell in obstacle_cells:
			return false
		for obs in cover_obstacles:
			if cell in get_occupied_cells(obs["pos"], obs["shape"]):
				return false
	return true

func move_enemy_toward(target: Vector2i, move_range: int) -> bool:
	var best_pos := enemy_pos
	var best_dist := movement_distance(enemy_pos, target)
	for dx in range(-move_range, move_range + 1):
		for dy in range(-move_range, move_range + 1):
			var candidate := enemy_pos + Vector2i(dx, dy)
			if movement_distance(enemy_pos, candidate) > float(move_range):
				continue
			if not can_place_enemy(candidate):
				continue
			var dist := movement_distance(candidate, target)
			if dist < best_dist:
				best_dist = dist
				best_pos = candidate
	if best_pos == enemy_pos:
		return false
	enemy_pos = best_pos
	queue_redraw()
	return true

func is_player_in_melee_range() -> bool:
	var enemy_cells = get_occupied_cells(enemy_pos, enemy_shape)
	var player_cells = get_occupied_cells(player_pos, player_shape)
	for e in enemy_cells:
		for p in player_cells:
			if abs(e.x - p.x) + abs(e.y - p.y) == 1:
				return true
	return false

func start_trap_placement(trap_range: int) -> void:
	selected_trap_range = trap_range
	queue_redraw()

func clear_trap_placement() -> void:
	selected_trap_range = 0
	queue_redraw()

func place_trap(pos: Vector2i, radius: int, damage: int, card_name: String) -> void:
	trap_zones.append({"pos": pos, "radius": radius, "damage": damage, "name": card_name})
	queue_redraw()

func check_and_trigger_traps(unit_pos: Vector2i, unit_shape: Array) -> int:
	var total_damage := 0
	var triggered: Array = []
	for trap in trap_zones:
		for cell in get_occupied_cells(unit_pos, unit_shape):
			if movement_distance(trap["pos"], cell) <= float(trap["radius"]):
				total_damage += trap["damage"]
				triggered.append(trap)
				break
	for trap in triggered:
		trap_zones.erase(trap)
	if triggered.size() > 0:
		queue_redraw()
	return total_damage

func check_and_trigger_traps_along_path(path: Array[Vector2i], unit_shape: Array) -> int:
	if path.size() <= 1:
		return 0
	var total_damage := 0
	var triggered: Array = []
	for trap in trap_zones:
		if trap in triggered:
			continue
		for step in path.slice(1):  # skip starting position
			var hit := false
			for cell in get_occupied_cells(step, unit_shape):
				if movement_distance(trap["pos"], cell) <= float(trap["radius"]):
					hit = true
					break
			if hit:
				total_damage += trap["damage"]
				triggered.append(trap)
				break
	for trap in triggered:
		trap_zones.erase(trap)
	if triggered.size() > 0:
		queue_redraw()
	return total_damage

func calculate_grenade_landing(from: Vector2i, target: Vector2i, bounce: float) -> Vector2i:
	if bounce == 0.0:
		return target
	var dir := Vector2(target - from).normalized()
	var bounce_dist := bounce * 20.0
	var random_angle := randf_range(-PI / 5.0, PI / 5.0)
	var bounced_dir := dir.rotated(random_angle)
	var offset := Vector2i(roundi(bounced_dir.x * bounce_dist), roundi(bounced_dir.y * bounce_dist))
	var landing := target + offset
	landing.x = clampi(landing.x, 0, grid_width - 1)
	landing.y = clampi(landing.y, 0, grid_height - 1)
	return landing

func show_grenade_preview(landing: Vector2i, aoe_radius: int) -> void:
	grenade_landing = landing
	grenade_aoe_radius = aoe_radius
	queue_redraw()

func clear_grenade_preview() -> void:
	grenade_landing = Vector2i(-1, -1)
	grenade_aoe_radius = 0
	queue_redraw()

func is_enemy_in_explosion(center: Vector2i, radius: int) -> bool:
	for e in get_occupied_cells(enemy_pos, enemy_shape):
		if movement_distance(center, e) <= float(radius):
			return true
	return false
