extends Control

signal tile_selected(cell: Vector2i)

var grid_width := 150
var grid_height := 150

var tile_width := 8
var tile_height := 4
var origin := Vector2(500, 80)

var player_pos := Vector2i(6, 8)
var enemy_pos := Vector2i(132, 135)

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
var enemy_hp := 35

func _ready() -> void:
	custom_minimum_size = Vector2(1200, 800)
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
			if selected_move_range > 0:
				var dist = movement_distance(player_pos, cell)
				if dist <= float(selected_move_range) and can_place_unit(cell, player_shape):
					highlight = true

			if highlight:
				draw_iso_tile(cell, Color(0.2, 0.4, 0.8, 0.20), true)
			else:
				draw_iso_tile(cell)

	draw_unit_footprint(player_pos, player_shape, Color(0.2, 0.8, 0.2))
	draw_unit_footprint(enemy_pos, enemy_shape, Color(0.8, 0.2, 0.2))

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

	for cell in get_occupied_cells(center, shape):
		if not is_inside_grid(cell):
			return false
		if cell in enemy_cells:
			return false

	return true

func start_move_selection(move_range: int) -> void:
	selected_move_range = move_range
	queue_redraw()

func clear_move_selection() -> void:
	selected_move_range = 0
	queue_redraw()

func try_move_player_to(cell: Vector2i, move_range: int) -> bool:
	var dist = movement_distance(player_pos, cell)
	if dist > float(move_range):
		return false

	if not can_place_unit(cell, player_shape):
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
