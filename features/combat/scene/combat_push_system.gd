class_name CombatPushSystem
extends RefCounted

## Selección, geometría y aplicación del desplazamiento forzado.
var map: Node

func start_enemy_selection(grab_range: float) -> void:
	map._show_disc(map._attack_disc, map.player_pos, grab_range + map._player_shadow_radius)
	map.start_enemy_highlight()

func start_enemy_cone(push_range: float) -> void:
	map._push_enemy_disc.visible = false
	var direction: Vector2 = (map.enemy_pos - map.player_pos).normalized()
	map._build_cone_disc(map._push_disc, map.enemy_pos, direction, push_range, 55.0)

func clear_selection() -> void:
	map._push_disc.visible = false
	map._push_enemy_disc.visible = false
	map._attack_disc.visible = false
	map.clear_enemy_highlight()
	map.clear_card_pattern_preview()

func is_pos_in_enemy_cone(pos: Vector2, push_range: float) -> bool:
	return _is_pos_in_cone(map.enemy_pos, map.player_pos, pos, push_range, 55.0)

func start_module_cone(module_pos: Vector2, push_range: float, half_angle: float = 55.0) -> void:
	map._attack_disc.visible = false
	var direction: Vector2 = (module_pos - map.player_pos).normalized()
	map._build_cone_disc(map._push_disc, module_pos, direction, push_range, half_angle)

func is_pos_in_module_cone(module_pos: Vector2, pos: Vector2, push_range: float, half_angle: float = 55.0) -> bool:
	return _is_pos_in_cone(module_pos, map.player_pos, pos, push_range, half_angle)

func calculate_push_landing(direction_target: Vector2, push_range: float) -> Vector2:
	var direction: Vector2 = (direction_target - map.enemy_pos).normalized()
	var target: Vector2 = map.enemy_pos + direction * push_range
	target = Vector2(clampf(target.x, 0.0, map.WORLD_W), clampf(target.y, 0.0, map.WORLD_H))
	return map._clip_path_at_obstacle(map.enemy_pos, target)

func calculate_drag_landing(toward: Vector2, distance: float) -> Vector2:
	var to_target: Vector2 = toward - map.enemy_pos
	var length: float = to_target.length()
	if length < 0.001:
		return map.enemy_pos
	var target: Vector2 = map.enemy_pos + to_target / length * minf(distance, length)
	return map._clip_path_at_obstacle(map.enemy_pos, target)

func push_enemy_to(landing: Vector2) -> void:
	var separation: Vector2 = landing - map.player_pos
	if separation.length() < map.MIN_SEPARATION:
		landing = map.player_pos + (separation.normalized() if separation.length() > 0.001 else Vector2(map.MIN_SEPARATION, 0.0)) * map.MIN_SEPARATION
	map.enemy_pos = landing
	map.enemy_elevation = map._elevation_at(landing)
	map._enemy_move_pending = true
	map._update_actor_positions()

func _is_pos_in_cone(origin: Vector2, source: Vector2, pos: Vector2, push_range: float, half_angle: float) -> bool:
	var to_pos: Vector2 = pos - origin
	if to_pos.length() < 0.001 or to_pos.length() > push_range:
		return false
	var direction: Vector2 = (origin - source).normalized()
	return absf(direction.angle_to(to_pos.normalized())) <= deg_to_rad(half_angle)
