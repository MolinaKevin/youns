class_name CombatPushSystem
extends RefCounted

## Selección, geometría y aplicación del desplazamiento forzado.
var map: MapArea

func start_enemy_selection(grab_range: float) -> void:
	map.presentation.show_push_enemy_selection(grab_range)
	map.presentation.show_enemy_highlight()

func start_enemy_cone(push_range: float) -> void:
	var direction: Vector2 = (map.enemy_pos - map.player_pos).normalized()
	map.presentation.show_push_cone(map.enemy_pos, direction, push_range, 55.0)

func clear_selection() -> void:
	map.presentation.clear_push_selection()
	map.presentation.clear_enemy_highlight()
	map.presentation.clear_card_pattern()

func is_pos_in_enemy_cone(pos: Vector2, push_range: float) -> bool:
	return _is_pos_in_cone(map.enemy_pos, map.player_pos, pos, push_range, 55.0)

func start_module_cone(module_pos: Vector2, push_range: float, half_angle: float = 55.0) -> void:
	map.presentation.hide_attack_range()
	var direction: Vector2 = (module_pos - map.player_pos).normalized()
	map.presentation.show_push_cone(module_pos, direction, push_range, half_angle)

func is_pos_in_module_cone(module_pos: Vector2, pos: Vector2, push_range: float, half_angle: float = 55.0) -> bool:
	return _is_pos_in_cone(module_pos, map.player_pos, pos, push_range, half_angle)

func calculate_push_landing(direction_target: Vector2, push_range: float) -> Vector2:
	var direction: Vector2 = (direction_target - map.enemy_pos).normalized()
	var target: Vector2 = map.enemy_pos + direction * push_range
	target = map.terrain.clamp_to_bounds(target)
	return map.terrain.clip_path_at_obstacle(map.enemy_pos, target)

func calculate_drag_landing(toward: Vector2, distance: float) -> Vector2:
	var to_target: Vector2 = toward - map.enemy_pos
	var length: float = to_target.length()
	if length < 0.001:
		return map.enemy_pos
	var target: Vector2 = map.enemy_pos + to_target / length * minf(distance, length)
	return map.terrain.clip_path_at_obstacle(map.enemy_pos, target)

func push_enemy_to(landing: Vector2) -> void:
	var separation: Vector2 = landing - map.player_pos
	if separation.length() < map.MIN_SEPARATION:
		landing = map.player_pos + (separation.normalized() if separation.length() > 0.001 else Vector2(map.MIN_SEPARATION, 0.0)) * map.MIN_SEPARATION
	map.enemy_pos = landing
	map.enemy_elevation = map.terrain.elevation_at(landing)
	map.actors.mark_enemy_move_pending()
	map.update_actor_positions()

func _is_pos_in_cone(origin: Vector2, source: Vector2, pos: Vector2, push_range: float, half_angle: float) -> bool:
	var to_pos: Vector2 = pos - origin
	if to_pos.length() < 0.001 or to_pos.length() > push_range:
		return false
	var direction: Vector2 = (origin - source).normalized()
	return absf(direction.angle_to(to_pos.normalized())) <= deg_to_rad(half_angle)
