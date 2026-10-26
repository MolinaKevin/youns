class_name CombatActorMover
extends RefCounted

## Interpola vistas, waypoints, giro y animaciones; MapArea mantiene el estado lógico.
signal enemy_reached_target
var map: MapArea
var player_waypoints: Array[Vector3] = []
var enemy_waypoints: Array[Vector3] = []
var enemy_move_pending := false

func clear_player_waypoints() -> void:
	player_waypoints.clear()

func add_player_waypoint(waypoint: Vector3) -> void:
	player_waypoints.append(waypoint)

func has_player_waypoints() -> bool:
	return not player_waypoints.is_empty()

func set_player_final_waypoint(waypoint: Vector3) -> void:
	if not player_waypoints.is_empty():
		player_waypoints[-1] = waypoint

func clear_enemy_waypoints() -> void:
	enemy_waypoints.clear()

func add_enemy_waypoint(waypoint: Vector3) -> void:
	enemy_waypoints.append(waypoint)

func mark_enemy_move_pending() -> void:
	enemy_move_pending = true

func update(delta: float) -> void:
	var player_view: CombatActorView = map.actors.player_view()
	var enemy_view: CombatActorView = map.actors.enemy_view()
	var step: float = map.ACTOR_MOVE_SPEED * delta
	var previous_player: Vector3 = player_view.position
	var player_goal: Vector3 = map.actors.player_target()
	if not player_waypoints.is_empty():
		player_goal = player_waypoints[0]
	player_view.position = player_view.position.move_toward(player_goal, step)
	if not player_waypoints.is_empty() and player_view.position.distance_to(player_goal) < 0.05:
		player_waypoints.pop_front()
	var player_moved: float = previous_player.distance_to(player_view.position)
	if player_view.current_anim not in map.actors.player_priority_animations():
		var player_direction: Vector3
		if player_moved > 0.001:
			player_direction = player_goal - previous_player
			map.actors.play_player_animation("run" if "run" in player_view.bodies else "walk")
		else:
			player_direction = enemy_view.position - player_view.position
			map.actors.play_player_animation("idle")
		player_direction.y = 0.0
		if player_direction.length() > 0.001:
			player_view.rotation.y = lerp_angle(player_view.rotation.y, atan2(player_direction.x, player_direction.z), map.actors.player_rotate_speed() * delta)

	var previous_enemy: Vector3 = enemy_view.position
	var enemy_goal: Vector3 = map.actors.enemy_target()
	if not enemy_waypoints.is_empty():
		enemy_goal = enemy_waypoints[0]
	enemy_view.position = enemy_view.position.move_toward(enemy_goal, step)
	if not enemy_waypoints.is_empty() and enemy_view.position.distance_to(enemy_goal) < 0.05:
		enemy_waypoints.pop_front()
	var enemy_moved: float = previous_enemy.distance_to(enemy_view.position)
	var enemy_direction: Vector3 = player_view.position - enemy_view.position
	enemy_direction.y = 0.0
	if enemy_direction.length() > 0.001:
		enemy_view.rotation.y = lerp_angle(enemy_view.rotation.y, atan2(enemy_direction.x, enemy_direction.z), map.actors.enemy_rotate_speed() * delta)
	if not enemy_view.bodies.is_empty() and enemy_view.current_anim not in map.actors.enemy_priority_animations():
		if enemy_moved > 0.001:
			enemy_view.play("run" if "run" in enemy_view.bodies else "walk")
		else:
			enemy_view.play("idle")
	if enemy_move_pending and enemy_view.position.distance_to(enemy_goal) < 0.05:
		enemy_move_pending = false
		enemy_reached_target.emit()
	map.presentation.place_status_labels()
	map.actors.refresh_shadows()
