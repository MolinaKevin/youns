class_name CombatActorMover
extends RefCounted

## Interpola vistas, waypoints, giro y animaciones; MapArea mantiene el estado lógico.
signal enemy_reached_target
var map: Node
var player_waypoints: Array[Vector3] = []
var enemy_waypoints: Array[Vector3] = []
var enemy_move_pending := false

func update(delta: float) -> void:
	var step: float = map.ACTOR_MOVE_SPEED * delta
	var previous_player: Vector3 = map._player_view.position
	var player_goal: Vector3 = map._player_target
	if not player_waypoints.is_empty():
		player_goal = player_waypoints[0]
	map._player_view.position = map._player_view.position.move_toward(player_goal, step)
	if not player_waypoints.is_empty() and map._player_view.position.distance_to(player_goal) < 0.05:
		player_waypoints.pop_front()
	var player_moved: float = previous_player.distance_to(map._player_view.position)
	if map._player_view.current_anim not in map._PRIORITY_ANIMS:
		var player_direction: Vector3
		if player_moved > 0.001:
			player_direction = player_goal - previous_player
			map.play_player_anim("run" if "run" in map._player_view.bodies else "walk")
		else:
			player_direction = map._enemy_view.position - map._player_view.position
			map.play_player_anim("idle")
		player_direction.y = 0.0
		if player_direction.length() > 0.001:
			map._player_view.rotation.y = lerp_angle(map._player_view.rotation.y, atan2(player_direction.x, player_direction.z), map._player_rotate_speed * delta)

	var previous_enemy: Vector3 = map._enemy_view.position
	var enemy_goal: Vector3 = map._enemy_target
	if not enemy_waypoints.is_empty():
		enemy_goal = enemy_waypoints[0]
	map._enemy_view.position = map._enemy_view.position.move_toward(enemy_goal, step)
	if not enemy_waypoints.is_empty() and map._enemy_view.position.distance_to(enemy_goal) < 0.05:
		enemy_waypoints.pop_front()
	var enemy_moved: float = previous_enemy.distance_to(map._enemy_view.position)
	var enemy_direction: Vector3 = map._player_view.position - map._enemy_view.position
	enemy_direction.y = 0.0
	if enemy_direction.length() > 0.001:
		map._enemy_view.rotation.y = lerp_angle(map._enemy_view.rotation.y, atan2(enemy_direction.x, enemy_direction.z), map._enemy_rotate_speed * delta)
	if not map._enemy_view.bodies.is_empty() and map._enemy_view.current_anim not in map._ENEMY_PRIORITY_ANIMS:
		if enemy_moved > 0.001:
			map._enemy_view.play("run" if "run" in map._enemy_view.bodies else "walk")
		else:
			map._enemy_view.play("idle")
	if enemy_move_pending and map._enemy_view.position.distance_to(map._enemy_target) < 0.05:
		enemy_move_pending = false
		enemy_reached_target.emit()
	map._place_status_labels()
	map._show_disc(map._player_shadow, Vector2(map._player_view.position.x, map._player_view.position.z), map._player_shadow_radius)
	map._show_disc(map._enemy_shadow, Vector2(map._enemy_view.position.x, map._enemy_view.position.z), map._enemy_shadow_radius)
