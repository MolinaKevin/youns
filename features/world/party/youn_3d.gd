extends CharacterBody3D

const PlaceholderModel := preload("res://features/world/party/placeholder_model.gd")
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

@export var youn_data: YounData

var _player: CharacterBody3D
## Bloquea el seguimiento horizontal sin tocar set_physics_process(), así la
## gravedad sigue actuando (p.ej. cutscenes donde el Youn tiene que caer).
var movement_locked := false
var _bodies: Dictionary = {}   # "idle" -> Node3D, "walk" -> Node3D, etc.
var _current_anim: String = ""
var _emotion_bubble: AnimatedSprite3D = null
var _recovering_to_player := false
var _normal_collision_mask := CollisionLayers.ACTOR_WORLD_MASK
var _recovery_path: Array[Vector2] = []
var _recovery_waypoint_index := 0
var _path_rebuild_timer := 0.0
var _recovery_stall_time := 0.0
var _recovery_best_distance := INF


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_normal_collision_mask = collision_mask | CollisionLayers.GROUND
	collision_mask = _normal_collision_mask
	_setup_emotion_bubble()
	if youn_data:
		_load_model(youn_data)


func load_youn(data: YounData) -> void:
	youn_data = data
	for body in _bodies.values():
		body.queue_free()
	_bodies.clear()
	_current_anim = ""
	_load_model(data)
	if _emotion_bubble:
		_emotion_bubble._update_height()


func _load_model(data: YounData) -> void:
	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var scene_map: Dictionary = {
		"idle":    data.scene_idle,
		"walk":    data.scene_walk,
		"run":     data.scene_run,
		"attack":  data.scene_attack,
		"range":   data.scene_range,
		"damage":  data.scene_damage,
		"die":     data.scene_die,
		"evolve":  data.scene_evolve,
	}

	for key in scene_map:
		var packed: PackedScene = scene_map[key]
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * data.mesh_scale
		body.position.y = data.mesh_y_offset
		body.rotation.y = data.mesh_rotation_y
		body.visible = false
		add_child(body)
		if mat:
			for mesh in Node3DSearch.find_meshes(body):
				mesh.material_override = mat
		_bodies[key] = body

	# Youn sin modelo todavía: uno de primitivas (PlaceholderModel), para que se vea.
	if _bodies.is_empty():
		_bodies["idle"] = PlaceholderModel.build(data)
		_bodies["idle"].visible = false
		add_child(_bodies["idle"])
	print("EmotionBubble loaded bodies: ", _bodies.keys())
	_switch_to("idle")


func _switch_to(anim_key: String) -> void:
	# Si la animación pedida no existe, cae al idle
	var target := anim_key if anim_key in _bodies else "idle"
	if _current_anim == target:
		return
	if _current_anim in _bodies:
		_bodies[_current_anim].visible = false
	_current_anim = target
	if target in _bodies:
		var body: Node3D = _bodies[target]
		body.visible = true
		var anim_player := Node3DSearch.find_anim_player(body)
		if anim_player:
			var list := anim_player.get_animation_list()
			if not list.is_empty():
				var anim_name := list[0]
				var anim := anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				anim_player.play(anim_name)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if movement_locked:
		velocity.x = 0.0
		velocity.z = 0.0
		_recovering_to_player = false
		collision_mask = _normal_collision_mask
		_switch_to("idle")
		move_and_slide()
		return

	if not _player:
		move_and_slide()
		return
	var to_player := _player.global_position - global_position
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
	var current_speed := Vector2(velocity.x, velocity.z).length()
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
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_dir(dir, delta)
		_switch_to("walk" if speed <= WALK_ANIMATION_MAX_SPEED else "run")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_switch_to("idle")

	move_and_slide()


func _begin_recovery() -> void:
	_recovering_to_player = true
	collision_mask = CollisionLayers.GROUND
	_path_rebuild_timer = 0.0
	_recovery_stall_time = 0.0
	_recovery_best_distance = INF
	_refresh_recovery_path()


func _end_recovery() -> void:
	_recovering_to_player = false
	collision_mask = _normal_collision_mask
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
	global_position = safe_ground_position + Vector3.UP * height_above_ground
	velocity = Vector3.ZERO
	_end_recovery()
	return true


func _ground_below(world_position: Vector3) -> Variant:
	if not is_inside_tree():
		return null
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * 20.0,
		world_position + Vector3.DOWN * 40.0,
		CollisionLayers.GROUND
	)
	query.exclude = [get_rid(), _player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("position")


func _move_through_obstacles(speed: float, delta: float) -> void:
	# Sigue usando física: al filtrar la máscara a GROUND atraviesa muros y
	# árboles. La ruta A* sólo atraviesa celdas caminables de WorldBoundary, así
	# evita cañones aunque el jugador esté abajo de una rampa en zigzag.
	if _move_along_world_path(speed, delta):
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_switch_to("idle")
	move_and_slide()


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
	var to_target := target - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.01:
		var dir := to_target / dist
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_dir(dir, delta)
		_switch_to("walk" if speed <= WALK_ANIMATION_MAX_SPEED else "run")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_switch_to("idle")
	move_and_slide()
	return true


func _refresh_recovery_path() -> void:
	_path_rebuild_timer = PATH_REBUILD_INTERVAL
	_recovery_path = ZoneManager.find_world_path(global_position, _player.global_position)
	_recovery_waypoint_index = 0


func _waypoint_is_reached(cell: Vector2) -> bool:
	var waypoint := _path_to_world(cell)
	return Vector2(global_position.x - waypoint.x, global_position.z - waypoint.z).length() <= WAYPOINT_REACHED_DISTANCE


func _path_to_world(cell: Vector2) -> Vector3:
	return Vector3(cell.x, global_position.y, cell.y)


func play_anim(anim_key: String) -> void:
	_switch_to(anim_key)

func get_current_anim() -> String:
	return _current_anim


func show_emotion(state_name: String) -> void:
	if _emotion_bubble:
		_emotion_bubble.show_emotion(state_name)


func get_active_emotions() -> Array[String]:
	if _emotion_bubble:
		return _emotion_bubble.get_active_emotions()
	return []


func _face_dir(dir: Vector3, delta: float) -> void:
	var rotate_speed := youn_data.rotate_speed if youn_data else 8.0
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, rotate_speed * delta)




# ── Emotion bubble ────────────────────────────────────────────────────────────

func _setup_emotion_bubble() -> void:
	var bubble := get_node_or_null("EmotionBubble") as AnimatedSprite3D
	if bubble == null:
		bubble = AnimatedSprite3D.new()
		bubble.set_script(preload("res://features/world/party/emotion_bubble.gd"))
		bubble.name = "EmotionBubble"
		add_child(bubble)

	var bubble_path := "res://assets/emotions/bubble_frames.tres"
	var bubble_frames: SpriteFrames
	if ResourceLoader.exists(bubble_path):
		bubble_frames = load(bubble_path)
	else:
		bubble_frames = _build_bubble_frames()
		ResourceSaver.save(bubble_frames, bubble_path)

	var icon_path := "res://assets/emotions/emotion_frames.tres"
	var icon_frames: SpriteFrames
	if ResourceLoader.exists(icon_path):
		icon_frames = load(icon_path)
		if not icon_frames.has_animation("evolving"):
			_patch_emotion_frames(icon_frames)
			ResourceSaver.save(icon_frames, icon_path)
	else:
		icon_frames = _build_emotion_frames()
		ResourceSaver.save(icon_frames, icon_path)

	bubble.call("setup", bubble_frames, icon_frames)
	_emotion_bubble = bubble


# SpriteFrames de la burbuja: "idle" (flota) y "pop" (explosión)
func _build_bubble_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()

	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", load("res://assets/emotions/bubble.png"))

	# pop: frames placeholder — ajustar en el editor con bubble_frames.tres
	sf.add_animation("pop")
	sf.set_animation_speed("pop", 10.0)
	sf.set_animation_loop("pop", false)
	var tex: Texture2D = load("res://assets/emotions/mixed.png")
	for region in [Rect2(296, 58, 80, 58), Rect2(385, 58, 62, 58), Rect2(383, 0, 66, 58)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		sf.add_frame("pop", atlas)

	return sf


func _patch_emotion_frames(sf: SpriteFrames) -> void:
	const CELL_W   := 40
	const CELL_H   := 58
	const OFFSET_X := 15
	var tex: Texture2D = load("res://assets/emotions/mixed.png")
	sf.add_animation("evolving")
	sf.set_animation_speed("evolving", 4.0)
	sf.set_animation_loop("evolving", true)
	for cell in [[4, 0], [5, 0], [6, 0]]:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(OFFSET_X + cell[0] * CELL_W, cell[1] * CELL_H, CELL_W, CELL_H)
		sf.add_frame("evolving", atlas)


# SpriteFrames de los íconos de emoción
func _build_emotion_frames() -> SpriteFrames:
	const CELL_W   := 40
	const CELL_H   := 58
	const OFFSET_X := 15

	# Fila 0 (y=0):   [0]=burbuja vacía · [1-3]=manzana · [4-6]=swirl · [7-8]=calavera
	# Fila 1 (y=58):  [0-1]=stress/cura · [2-3]=mariposa · [4-6]=sparkle
	# Fila 2 (y=116): [0-2]=ciervo · [3-4]=gotas · [5-7]=ZZZ

	# [nombre, fps, loop, [[col, fila], ...]]
	var defs: Array = [
		["hungry",   5.0, true, [[1,0],[2,0],[3,0]]],
		["tired",    4.0, true, [[4,0],[5,0],[6,0]]],
		["sick",     4.0, true, [[7,0],[8,0]]],
		["stressed", 3.0, true, [[0,1]]],
		["bored",    6.0, true, [[2,1],[3,1]]],
		["sad",      4.0, true, [[3,2],[4,2]]],
		["sleep",    3.0, true, [[5,2],[6,2],[7,2]]],
		["evolving", 4.0, true, [[4,0],[5,0],[6,0]]],  # placeholder: mismas frames que tired
	]

	var tex: Texture2D = load("res://assets/emotions/mixed.png")
	var sf := SpriteFrames.new()
	for entry in defs:
		var anim_name: String = entry[0]
		var fps: float        = entry[1]
		var loop: bool        = entry[2]
		var cells: Array      = entry[3]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		for cell in cells:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(OFFSET_X + cell[0] * CELL_W, cell[1] * CELL_H, CELL_W, CELL_H)
			sf.add_frame(anim_name, atlas)
	return sf
