extends Node

## Cinemática de "ir al baño": arranca sola cuando el Youn entra a `$ToiletArea`
## y el estado "bathroom" está activo. Toda la geometría (dónde está el
## inodoro, desde dónde se entra, cómo se encuadra la cámara) sale de
## `toilet_data`, así que esta escena no depende de la zona donde vive.
@export var toilet_data: ToiletData

var _running := false
var _youn_inside := false
var _scene3d: CutsceneScene3D
var _world_lease: WorldTransitionLease
var _flow: AsyncFlowToken
var _camera_pivot: Node3D
var _player: Node3D
var _youn: Node3D
var _camera: Node3D

@onready var _area: Area3D = $ToiletArea


func _ready() -> void:
	_scene3d = CutsceneScene3D.new(self)
	_area.body_entered.connect(_on_area_entered)
	_area.body_exited.connect(_on_area_exited)


func _process(_delta: float) -> void:
	if _youn_inside:
		_try_start()


func _on_area_entered(body: Node3D) -> void:
	if body == PartyManager.youn:
		_youn_inside = true
		_try_start()


func _on_area_exited(body: Node3D) -> void:
	if body == PartyManager.youn:
		_youn_inside = false


func _try_start() -> void:
	if _running:
		return
	if not PlayerSessionAccess.has_active_save() or not StatsManager.services.emotions().has_state("bathroom"):
		return
	_run()


func _run() -> void:
	_running = true
	_flow = AsyncFlowToken.new(self)
	_player = PartyManager.player
	_youn = PartyManager.youn
	_camera = PartyManager.camera_rig
	if not is_instance_valid(_player) or not is_instance_valid(_youn) or not is_instance_valid(_camera):
		_finish()
		return
	var player := _player
	var youn := _youn
	var cam := _camera

	# ── Marcas explícitas de la cinemática ────────────────────────────────────
	# Cada baño define estas posiciones en su ToiletData, así la secuencia se
	# reutiliza en otra zona sin depender de distancias o ejes implícitos.
	var td := toilet_data if toilet_data else ToiletData.new()
	var start_pos: Vector3 = td.player_start_position
	var meeting_point: Vector3 = td.youn_start_position
	var entrance_pos: Vector3 = td.youn_entrance_position
	var toilet_pos: Vector3 = td.youn_inside_position
	var camera_focus: Vector3 = td.camera_focus_position

	StatsManager.services.care().attend_bathroom()

	# La secuencia puede desaparecer junto con la zona: el lease garantiza que
	# no deja reloj, cámara o actores congelados en ese caso.
	_world_lease = WorldTransitionLease.new(
		ModalScreenHost.from_runtime(), PartyManager,
		{"show_mouse": false}
	)

	var player_original_rot_y := player.rotation.y

	var to_toilet_flat: Vector3 = toilet_pos - meeting_point
	to_toilet_flat.y = 0.0
	var toilet_dir: Vector3 = to_toilet_flat.normalized() if to_toilet_flat.length() > 0.1 else Vector3(0, 0, -1)
	var perp:          Vector3 = Vector3(-toilet_dir.z, 0.0, toilet_dir.x)

	# ── Cámara: tween suave al ángulo ideal en paralelo con el paso 0 ─────────
	var cam_yaw_start:   float = cam.yaw
	var cam_pitch_start: float = cam.pitch
	var cam_dist_start:  float = cam.distance
	var cam_ideal_yaw   := atan2(perp.x * td.cam_side, perp.z * td.cam_side)
	var tw_cam := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_cam.tween_method(func(t: float) -> void:
		cam.yaw      = lerp_angle(cam_yaw_start, cam_ideal_yaw, t)
		cam.pitch    = lerpf(cam_pitch_start, td.cam_pitch, t)
		cam.distance = lerpf(cam_dist_start, td.cam_distance, t),
		0.0, 1.0, 1.2)

	# ── 0. Player y Youn caminan distto al punto de arranque ──────────────────
	youn.play_anim("walk")
	player.set_anim_base("walk")
	_face_toward(player, start_pos)

	var dist_p    := Vector2(player.global_position.x - start_pos.x,
								 player.global_position.z - start_pos.z).length()
	var dist_y := Vector2(youn.global_position.x - meeting_point.x,
		youn.global_position.z - meeting_point.z).length()
	var dur_player := clampf(dist_p / 2.5, 0.3, 4.0)
	var dur_youn := clampf(dist_y / 2.5, 0.3, 4.0)

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position", start_pos, dur_player)
	_face_toward(youn, meeting_point)
	tw.parallel().tween_property(youn, "global_position", meeting_point, dur_youn)
	await tw.finished
	if not _flow_is_active():
		_finish()
		return

	# Pivot de cámara para encuadrar a ambos en los momentos de mirada
	_camera_pivot = Node3D.new()
	add_child(_camera_pivot)
	_camera_pivot.global_position = camera_focus + Vector3.UP * td.cam_pivot_height

	# ── 1. Se miran — cámara al centro ───────────────────────────────────────
	cam.target = _camera_pivot
	youn.play_anim("idle")
	player.set_anim_base("idle")
	_face_toward(youn, start_pos)
	_face_toward(player, meeting_point)
	await get_tree().create_timer(1.0).timeout
	if not _flow_is_active():
		_finish()
		return

	# ── 2. Youn va al baño — jugador lo sigue con la mirada ──────────────────
	cam.target = youn
	youn.play_anim("walk")
	_face_toward(youn, entrance_pos)
	var rot_start  := player.rotation.y
	var rot_target := _scene3d.yaw_toward(start_pos, toilet_pos)
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(youn, "global_position", entrance_pos, 1.0)
	tw.parallel().tween_method(
		func(t: float): player.rotation.y = lerp_angle(rot_start, rot_target, t),
		0.0, 1.0, 0.8)
	await tw.finished
	if not _flow_is_active():
		_finish()
		return

	# Youn entra al cilindro mirando hacia él
	_face_toward(youn, toilet_pos)
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(youn, "global_position", toilet_pos, 0.5)
	await tw.finished
	if not _flow_is_active():
		_finish()
		return
	youn.visible = false
	youn.play_anim("idle")

	# ── 3. Esperar adentro ────────────────────────────────────────────────────
	await get_tree().create_timer(td.wait_inside).timeout
	if not _flow_is_active():
		_finish()
		return

	# ── 4. Youn sale y vuelve al meeting point ────────────────────────────────
	youn.global_position = entrance_pos
	youn.visible = true
	youn.play_anim("walk")
	cam.target = youn
	_face_toward(youn, meeting_point)
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(youn, "global_position", meeting_point, 1.0)
	await tw.finished
	if not _flow_is_active():
		_finish()
		return
	youn.play_anim("idle")

	# ── 5. Se miran de nuevo — pausa ─────────────────────────────────────────
	cam.target = _camera_pivot
	_face_toward(youn, start_pos)
	_face_toward(player, meeting_point)
	await get_tree().create_timer(0.8).timeout
	if not _flow_is_active():
		_finish()
		return

	# ── 6. Cámara vuelve al jugador — jugador se da vuelta ───────────────────
	cam.target = player
	var final_rot_start := player.rotation.y
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(t: float): player.rotation.y = lerp_angle(final_rot_start, player_original_rot_y, t),
		0.0, 1.0, 0.5)
	tw.parallel().tween_method(func(t: float) -> void:
		cam.pitch    = lerpf(td.cam_pitch, cam_pitch_start, t)
		cam.distance = lerpf(td.cam_distance, cam_dist_start, t),
		0.0, 1.0, 0.5)
	await tw.finished
	if not _flow_is_active():
		_finish()
		return

	_finish()


func _exit_tree() -> void:
	if _flow:
		_flow.cancel()
	_finish()


func _flow_is_active() -> bool:
	return _flow != null and _flow.is_active()


## Ruta única de salida: una cancelación no puede dejar el mundo congelado ni
## al Youn invisible si la zona sigue viva.
func _finish() -> void:
	if is_instance_valid(_youn):
		_youn.visible = true
	if is_instance_valid(_camera) and is_instance_valid(_player):
		_camera.target = _player
	if is_instance_valid(_camera_pivot):
		_camera_pivot.queue_free()
	_camera_pivot = null
	if _world_lease:
		_world_lease.release()
	_world_lease = null
	_flow = null
	_running = false


## Igual que CutsceneScene3D.face(), pero sin tocar la rotación si ya está
## pegado al target (CutsceneScene3D.yaw_toward() devolvería 0 y lo haría
## mirar al frente del mundo en vez de dejarlo como está).
func _face_toward(node: Node3D, target: Vector3) -> void:
	var d: Vector3 = target - node.global_position
	d.y = 0.0
	if d.length() > 0.05:
		node.rotation.y = _scene3d.yaw_toward(node.global_position, target)
