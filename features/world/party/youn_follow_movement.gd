class_name YounFollowMovement
extends RefCounted

## Seguimiento del compañero al jugador: elástico cerca del jugador, con
## "catch up" si queda lejos, y un modo de recuperación (ignora obstáculos,
## sigue la ruta A* del mundo) si se queda muy atrás. Como último recurso, si
## ni la recuperación lo logra, teletransporta al Youn junto al jugador. No
## sabe nada del modelo ni de la burbuja de emociones — host es el Youn3D
## dueño exclusivo de esta instancia.

const CollisionLayers := preload("res://shared/world_collision_layers.gd")

const GRAVITY := 20.0
## El Youn arranca a seguir recién al abrir esta distancia.
const FOLLOW_START_DIST := 2.0
## A esta separación ya usa la velocidad completa del jugador.
const FOLLOW_FULL_SPEED_DIST := 5.0
## A partir de acá el Youn suma velocidad extra para recuperar terreno. No se
## limita a la velocidad del jugador: cuanto más lejos queda, más rápido vuelve.
const CATCH_UP_START_DIST := 5.0
const CATCH_UP_SPEED_PER_METER := 1.5
const MAX_CATCH_UP_SPEED := 20.0
## Aceleración/frenado horizontal; produce el seguimiento con inercia.
const FOLLOW_ACCELERATION := 12.0
const FOLLOW_DECELERATION := 7.0
const WALK_ANIMATION_MAX_SPEED := 4.0
## Al cruzar esta distancia, el Youn entra en recuperación: ignora obstáculos,
## pero sigue colisionando con la capa de suelo. Hay histéresis para que no
## alterne de estado cada frame al llegar junto al jugador.
const RECOVERY_START_DISTANCE := 15.0
const RECOVERY_END_DISTANCE := 4.0
## La ruta A* se recalcula periódicamente mientras recupera distancia: sigue
## rampas y caminos transitables, sin intentar cortar un cañón en diagonal.
const PATH_REBUILD_INTERVAL := 0.5
const WAYPOINT_REACHED_DISTANCE := 0.65
## Último recurso: si ni siquiera el modo de recuperación logra acercarlo,
## vuelve junto al jugador. El margen largo evita que ocurra durante un rodeo
## legítimo de la ruta.
const STUCK_TELEPORT_TIMEOUT := 6.0
const STUCK_PROGRESS_DISTANCE := 0.75
const TELEPORT_FOLLOW_DISTANCE := 9.0

var host: Youn3D
var _player: CharacterBody3D
var _normal_collision_mask: int
var _recovering_to_player := false
var _recovery_path: Array[Vector2] = []
var _recovery_waypoint_index := 0
var _path_rebuild_timer := 0.0
var _recovery_stall_time := 0.0
var _recovery_best_distance := INF

func _init(p_host: Youn3D) -> void:
	host = p_host
	_player = host.get_parent().get_node_or_null("Player")
	_normal_collision_mask = host.collision_mask | CollisionLayers.GROUND
	host.collision_mask = _normal_collision_mask

func tick(delta: float) -> void:
	if not host.is_on_floor():
		host.velocity.y -= GRAVITY * delta

	if host.movement_locked:
		host.velocity.x = 0.0
		host.velocity.z = 0.0
		_recovering_to_player = false
		host.collision_mask = _normal_collision_mask
		host.play_anim("idle")
		host.move_and_slide()
		return

	if not _player:
		host.move_and_slide()
		return
	var to_player := _player.global_position - host.global_position
	to_player.y = 0.0
	var dist := to_player.length()

	# Seguimiento elástico: cerca conserva el ritmo del jugador; lejos agrega
	# velocidad según la separación para poder alcanzarlo después de una carrera.
	var max_follow_speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if _player.has_method("movement_speed"):
		max_follow_speed = _player.movement_speed()
	var distance_ratio := inverse_lerp(FOLLOW_START_DIST, FOLLOW_FULL_SPEED_DIST, dist)
	var normal_speed := max_follow_speed * clampf(distance_ratio, 0.0, 1.0)
	var catch_up_speed := maxf(0.0, dist - CATCH_UP_START_DIST) * CATCH_UP_SPEED_PER_METER
	var target_speed := minf(normal_speed + catch_up_speed, MAX_CATCH_UP_SPEED)
	var current_speed := Vector2(host.velocity.x, host.velocity.z).length()
	var rate := FOLLOW_ACCELERATION if target_speed > current_speed else FOLLOW_DECELERATION
	var speed := move_toward(current_speed, target_speed, rate * delta)

	if not _recovering_to_player and dist >= RECOVERY_START_DISTANCE:
		_begin_recovery()
	elif _recovering_to_player and dist <= RECOVERY_END_DISTANCE:
		if _recovery_waypoint_index >= _recovery_path.size():
			_end_recovery()

	if _recovering_to_player:
		if _recovery_is_stuck(dist, delta):
			if _teleport_to_player_safely():
				return
			# No hay una superficie confirmada: conserva el modo de recuperación
			# y vuelve a intentarlo más tarde, sin arriesgar una caída.
			_recovery_stall_time = 0.0
		_move_through_obstacles(speed, delta)
		return

	# No intenta cortar en línea recta una rampa, curva o desnivel. También en
	# seguimiento normal usa la misma ruta A* de las celdas caminables; la
	# recuperación sólo cambia la máscara de colisión y la velocidad.
	if dist > FOLLOW_START_DIST and _move_along_world_path(speed, delta):
		return

	if speed > 0.01 and dist > 0.01:
		var dir := to_player / dist
		host.velocity.x = dir.x * speed
		host.velocity.z = dir.z * speed
		_face_dir(dir, delta)
		host.play_anim("walk" if speed <= WALK_ANIMATION_MAX_SPEED else "run")
	else:
		host.velocity.x = 0.0
		host.velocity.z = 0.0
		host.play_anim("idle")

	host.move_and_slide()


func _begin_recovery() -> void:
	_recovering_to_player = true
	host.collision_mask = CollisionLayers.GROUND
	_path_rebuild_timer = 0.0
	_recovery_stall_time = 0.0
	_recovery_best_distance = INF
	_refresh_recovery_path()


func _end_recovery() -> void:
	_recovering_to_player = false
	host.collision_mask = _normal_collision_mask
	_recovery_path.clear()
	_recovery_waypoint_index = 0
	_recovery_stall_time = 0.0
	_recovery_best_distance = INF


func _recovery_is_stuck(distance_to_player: float, delta: float) -> bool:
	# Cada avance significativo reinicia el contador. De este modo, una vuelta
	# larga por una rampa sigue siendo válida; sólo se recupera por teletransporte
	# cuando realmente no hubo progreso durante varios segundos.
	if distance_to_player <= _recovery_best_distance - STUCK_PROGRESS_DISTANCE:
		_recovery_best_distance = distance_to_player
		_recovery_stall_time = 0.0
	else:
		_recovery_stall_time += delta
	return _recovery_stall_time >= STUCK_TELEPORT_TIMEOUT


func _teleport_to_player_safely() -> bool:
	# Primero se propone la posición de seguimiento detrás del jugador. No se usa
	# directamente: la grilla la proyecta a una celda caminable conectada al
	# jugador, para que nunca sea un borde, agua o un precipicio.
	var forward := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if forward.length_squared() < 0.01:
		forward = Vector3(sin(_player.rotation.y), 0.0, cos(_player.rotation.y))
	else:
		forward = forward.normalized()
	var desired := _player.global_position - forward * TELEPORT_FOLLOW_DISTANCE
	var safe_path := ZoneManager.find_world_path(desired, _player.global_position)
	if safe_path.is_empty():
		return false
	var safe_xz := safe_path[0]
	var player_ground: Variant = _ground_below(_player.global_position)
	var safe_ground: Variant = _ground_below(Vector3(safe_xz.x, _player.global_position.y, safe_xz.y))
	if player_ground == null or safe_ground == null:
		return false
	# Conserva la distancia vertical real entre el origen del CharacterBody y el
	# suelo del jugador, pero aplicada al suelo de destino (útil en rampas).
	var player_ground_position: Vector3 = player_ground
	var safe_ground_position: Vector3 = safe_ground
	var height_above_ground := _player.global_position.y - player_ground_position.y
	host.global_position = safe_ground_position + Vector3.UP * height_above_ground
	host.velocity = Vector3.ZERO
	_end_recovery()
	return true


func _ground_below(world_position: Vector3) -> Variant:
	if not host.is_inside_tree():
		return null
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * 20.0,
		world_position + Vector3.DOWN * 40.0,
		CollisionLayers.GROUND
	)
	query.exclude = [host.get_rid(), _player.get_rid()]
	var hit := host.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position")


func _move_through_obstacles(speed: float, delta: float) -> void:
	# Sigue usando física: al filtrar la máscara a GROUND atraviesa muros y
	# árboles. La ruta A* sólo atraviesa celdas caminables de WorldBoundary, así
	# evita cañones aunque el jugador esté abajo de una rampa en zigzag.
	if _move_along_world_path(speed, delta):
		return
	host.velocity.x = 0.0
	host.velocity.z = 0.0
	host.play_anim("idle")
	host.move_and_slide()


func _move_along_world_path(speed: float, delta: float) -> bool:
	# Esta ruta se comparte entre el seguimiento normal y la recuperación. Si
	# no existe (por ejemplo, en interiores que no usan WorldBoundary), quien la
	# llama puede aplicar su comportamiento alternativo.
	_path_rebuild_timer -= delta
	if _path_rebuild_timer <= 0.0:
		_refresh_recovery_path()
	if _recovery_path.is_empty():
		return false
	while _recovery_waypoint_index < _recovery_path.size() and _waypoint_is_reached(_recovery_path[_recovery_waypoint_index]):
		_recovery_waypoint_index += 1
	if _recovery_waypoint_index >= _recovery_path.size():
		return false
	var target := _path_to_world(_recovery_path[_recovery_waypoint_index])
	var to_target := target - host.global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.01:
		var dir := to_target / dist
		host.velocity.x = dir.x * speed
		host.velocity.z = dir.z * speed
		_face_dir(dir, delta)
		host.play_anim("walk" if speed <= WALK_ANIMATION_MAX_SPEED else "run")
	else:
		host.velocity.x = 0.0
		host.velocity.z = 0.0
		host.play_anim("idle")
	host.move_and_slide()
	return true


func _refresh_recovery_path() -> void:
	_path_rebuild_timer = PATH_REBUILD_INTERVAL
	_recovery_path = ZoneManager.find_world_path(host.global_position, _player.global_position)
	_recovery_waypoint_index = 0


func _waypoint_is_reached(cell: Vector2) -> bool:
	var waypoint := _path_to_world(cell)
	return Vector2(host.global_position.x - waypoint.x, host.global_position.z - waypoint.z).length() <= WAYPOINT_REACHED_DISTANCE


func _path_to_world(cell: Vector2) -> Vector3:
	return Vector3(cell.x, host.global_position.y, cell.y)


func _face_dir(dir: Vector3, delta: float) -> void:
	var rotate_speed := host.youn_data.rotate_speed if host.youn_data else 8.0
	var target_angle := atan2(dir.x, dir.z)
	host.rotation.y = lerp_angle(host.rotation.y, target_angle, rotate_speed * delta)
