class_name CombatMapInput
extends Node

## Traduce mouse/pantalla a coordenadas del tablero. MapArea conserva las
## consultas de terreno para el gameplay, pero este componente es dueño del
## raycast de interacción, hover bloqueado y señal de clic.
signal position_selected(pos: Vector2)

var map: Node3D
var _hover_locked := false
var _last_click_pos := Vector2.ZERO

func _process(_delta: float) -> void:
	if map == null:
		return
	var camera := map.get_viewport().get_camera_3d()
	if camera == null:
		return
	if _hover_locked:
		map._update_hover_at(_last_click_pos)
		return
	var screen_pos := map.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	if abs(direction.y) < 0.001:
		map._clear_hover()
		return
	map._update_hover_at(_ray_to_terrain(from, direction))

func _unhandled_input(event: InputEvent) -> void:
	if map == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var camera := map.get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.project_ray_origin(event.position)
	var direction := camera.project_ray_normal(event.position)
	if abs(direction.y) < 0.001:
		return
	_last_click_pos = _ray_to_terrain(from, direction)
	position_selected.emit(_last_click_pos)

func lock_hover_at_last_click() -> void:
	_hover_locked = true

func unlock_hover() -> void:
	_hover_locked = false

func _ray_to_terrain(from: Vector3, direction: Vector3) -> Vector2:
	var best_t := INF
	for obstacle: Dictionary in map.solid_obstacles:
		if obstacle.get("type", "solid") != "platform":
			continue
		var center: Vector2 = obstacle["pos"]
		var half_size: Vector2 = obstacle["box"] * 0.5
		if abs(direction.y) > 0.0001:
			var top_t: float = (map.PLATFORM_HEIGHT - from.y) / direction.y
			if top_t > 0.001 and top_t < best_t:
				var top_hit := from + direction * top_t
				if abs(top_hit.x - center.x) <= half_size.x and abs(top_hit.z - center.y) <= half_size.y:
					best_t = top_t
		for ramp: Dictionary in obstacle.get("ramps", []):
			var ramp_t := _ray_to_ramp(from, direction, center, half_size, ramp)
			if ramp_t > 0.001 and ramp_t < best_t:
				best_t = ramp_t
	if abs(direction.y) > 0.0001:
		var ground_t: float = -from.y / direction.y
		if ground_t > 0.001 and ground_t < best_t:
			best_t = ground_t
	if best_t == INF:
		best_t = 1.0
	var hit := from + direction * best_t
	return Vector2(clampf(hit.x, 0.0, map.WORLD_W), clampf(hit.z, 0.0, map.WORLD_H))

func _ray_to_ramp(from: Vector3, direction: Vector3, center: Vector2, half_size: Vector2, ramp: Dictionary) -> float:
	var half_width: float = ramp.get("width", 2.0) * 0.5
	var side: String = ramp["side"]
	var platform_height: float = map.PLATFORM_HEIGHT
	var ramp_depth: float = map.RAMP_DEPTH
	var denominator: float
	var numerator: float
	match side:
		"south":
			denominator = ramp_depth * direction.y + platform_height * direction.z
			numerator = platform_height * (ramp_depth + center.y + half_size.y) - ramp_depth * from.y - platform_height * from.z
		"north":
			denominator = ramp_depth * direction.y - platform_height * direction.z
			numerator = platform_height * (ramp_depth - center.y + half_size.y) - ramp_depth * from.y + platform_height * from.z
		"east":
			denominator = ramp_depth * direction.y + platform_height * direction.x
			numerator = platform_height * (ramp_depth + center.x + half_size.x) - ramp_depth * from.y - platform_height * from.x
		"west":
			denominator = ramp_depth * direction.y - platform_height * direction.x
			numerator = platform_height * (ramp_depth - center.x + half_size.x) - ramp_depth * from.y + platform_height * from.x
		_:
			return -1.0
	if abs(denominator) < 0.0001:
		return -1.0
	var time := numerator / denominator
	if time <= 0.001:
		return -1.0
	var hit := from + direction * time
	match side:
		"south": if abs(hit.x - center.x) < half_width and hit.z >= center.y + half_size.y and hit.z <= center.y + half_size.y + ramp_depth: return time
		"north": if abs(hit.x - center.x) < half_width and hit.z <= center.y - half_size.y and hit.z >= center.y - half_size.y - ramp_depth: return time
		"east": if abs(hit.z - center.y) < half_width and hit.x >= center.x + half_size.x and hit.x <= center.x + half_size.x + ramp_depth: return time
		"west": if abs(hit.z - center.y) < half_width and hit.x <= center.x - half_size.x and hit.x >= center.x - half_size.x - ramp_depth: return time
	return -1.0
