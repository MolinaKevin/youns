class_name CombatOverwatchSystem
extends RefCounted

## Estado, previsualización y zona activa de overwatch.
var map: Node
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
	map._overwatch_preview_disc.visible = false
	preview_last_direction = Vector2.ZERO

func update_hover(pos: Vector2) -> void:
	if not selection_active:
		map._overwatch_preview_disc.visible = false
		return
	var to_mouse: Vector2 = pos - map.player_pos
	if to_mouse.length() <= 0.2:
		map._overwatch_preview_disc.visible = false
		return
	var direction := to_mouse.normalized()
	if direction.distance_to(preview_last_direction) > 0.015:
		preview_last_direction = direction
		map._overwatch_preview_disc.set_meta("fill_mat", map._make_mat(Color(1.0, 0.85, 0.1, 0.20)))
		map._overwatch_preview_disc.set_meta("bord_mat", map._make_mat(Color(1.0, 1.0, 0.35, 0.55)))
		map._build_cone_disc(map._overwatch_preview_disc, map.player_pos, direction, selection_range, selection_angle)
	map._overwatch_preview_disc.visible = true

func place(origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> void:
	map._overwatch_zone.set_meta("fill_mat", map._make_mat(Color(1.0, 0.85, 0.1, 0.22)))
	map._overwatch_zone.set_meta("bord_mat", map._make_mat(Color(1.0, 1.0, 0.35, 0.70)))
	map._build_cone_disc(map._overwatch_zone, origin, direction, cone_range, half_angle)

func clear_zone() -> void:
	map._overwatch_zone.visible = false

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
