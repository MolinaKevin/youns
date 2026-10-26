class_name CombatOverwatchSystem
extends RefCounted

## Estado, previsualización y zona activa de overwatch.
var map: MapArea
var selection_active := false
var selection_range := 0.0
var selection_angle := 10.0
var preview_last_direction := Vector2.ZERO

func start_selection(cone_range: float, half_angle: float) -> void:
	selection_active = true
	selection_range = cone_range
	selection_angle = half_angle
	preview_last_direction = Vector2.ZERO

func clear_selection() -> void:
	selection_active = false
	map.presentation.hide_overwatch_preview()
	preview_last_direction = Vector2.ZERO

func update_hover(pos: Vector2) -> void:
	if not selection_active:
		map.presentation.hide_overwatch_preview()
		return
	var to_mouse: Vector2 = pos - map.player_pos
	if to_mouse.length() <= 0.2:
		map.presentation.hide_overwatch_preview()
		return
	var direction := to_mouse.normalized()
	if direction.distance_to(preview_last_direction) > 0.015:
		preview_last_direction = direction
		map.presentation.show_overwatch_preview(map.player_pos, direction, selection_range, selection_angle)

func place(origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> void:
	map.presentation.show_overwatch_zone(origin, direction, cone_range, half_angle)

func clear_zone() -> void:
	map.presentation.clear_overwatch_zone()

func segment_crosses_cone(from: Vector2, to: Vector2, origin: Vector2, direction: Vector2, cone_range: float, half_angle_deg: float) -> bool:
	var half_angle := deg_to_rad(half_angle_deg)
	var steps := maxi(2, int(from.distance_to(to) / 0.3))
	for i in range(steps + 1):
		var pos: Vector2 = from.lerp(to, float(i) / float(steps))
		var to_pos: Vector2 = pos - origin
		if to_pos.length() < 0.001 or to_pos.length() > cone_range:
			continue
		if absf(direction.angle_to(to_pos.normalized())) <= half_angle:
			return true
	return false
