extends Node

## Cinemática de "ir al baño": arranca sola cuando el Youn entra a `$ToiletArea`
## y el estado "bathroom" está activo. Toda la geometría (dónde está el
## inodoro, desde dónde se entra, cómo se encuadra la cámara) sale de
## `toilet_data`, así que esta escena no depende de la zona donde vive.
@export var toilet_data: ToiletData

var _running := false
var _youn_inside := false
var _scene3d: CutsceneScene3D

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
	if GameState.player_save == null or "bathroom" not in StatsManager.active_states:
		return
	_run()


func _run() -> void:
	_running = true
	var player := PartyManager.player
	var youn   := PartyManager.youn
	var cam    := PartyManager.camera_rig

	StatsManager.attend_bathroom()

	# Freezar controles y reloj
	PartyManager.freeze_actors()
	PartyManager.freeze_camera()
	GlobalHUD.set_clock_paused(true)

	var player_original_rot_y := player.rotation.y

	# ── Posiciones desde el punto fijo de la escena ───────────────────────────
	# Usar el y actual de cada personaje para no perforar el suelo
	var player_y: float = player.global_position.y
	var youn_y: float   = youn.global_position.y

	var td := toilet_data if toilet_data else ToiletData.new()

	var start_xz: Vector3   = td.start_point
	var toilet_pos: Vector3 = td.world_position
	toilet_pos.y = youn_y

	var to_toilet_flat: Vector3 = toilet_pos - start_xz
	to_toilet_flat.y = 0.0
	var toilet_dir: Vector3 = to_toilet_flat.normalized() if to_toilet_flat.length() > 0.1 else Vector3(0, 0, -1)

	var start_pos:     Vector3 = Vector3(start_xz.x, player_y, start_xz.z)
	var meeting_point: Vector3 = Vector3(start_xz.x, youn_y, start_xz.z) + toilet_dir * td.meeting_distance
	var entrance_pos:  Vector3 = toilet_pos - toilet_dir * td.entrance_distance
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
	var youn_start := youn.global_position
	var y_to_p    := Vector3(youn_start.x - start_pos.x, 0.0, youn_start.z - start_pos.z)
	var side_dir  := perp if perp.dot(y_to_p) >= 0.0 else -perp
	var bypass_pt := Vector3(start_pos.x + side_dir.x * 1.5, youn_y, start_pos.z + side_dir.z * 1.5)

	youn.play_anim("walk")
	player.set_anim_base("walk")
	_face_toward(player, start_pos)

	var dist_p    := Vector2(player.global_position.x - start_pos.x,
							 player.global_position.z - start_pos.z).length()
	var dur_player := clampf(dist_p / 2.5, 0.3, 4.0)

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position", start_pos, dur_player)

	if _path_passes_near(youn_start, meeting_point, start_pos, 0.8):
		_face_toward(youn, bypass_pt)
		var dist_y1 := Vector2(youn_start.x - bypass_pt.x, youn_start.z - bypass_pt.z).length()
		var dist_y2 := Vector2(bypass_pt.x - meeting_point.x, bypass_pt.z - meeting_point.z).length()
		var dur_y1  := clampf(dist_y1 / 2.2, 0.2, 3.0)
		var dur_y2  := clampf(dist_y2 / 2.2, 0.2, 3.0)
		var tw_y := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_y.tween_property(youn, "global_position", bypass_pt, dur_y1)
		tw_y.tween_callback(func(): _face_toward(youn, meeting_point))
		tw_y.tween_property(youn, "global_position", meeting_point, dur_y2)
		await get_tree().create_timer(maxf(dur_player, dur_y1 + dur_y2)).timeout
	else:
		_face_toward(youn, meeting_point)
		var dist_y   := Vector2(youn_start.x - meeting_point.x, youn_start.z - meeting_point.z).length()
		var walk_dur := clampf(maxf(dist_p, dist_y) / 2.5, 0.4, 4.0)
		tw.parallel().tween_property(youn, "global_position", meeting_point, walk_dur)
		await tw.finished

	# Pivot de cámara para encuadrar a ambos en los momentos de mirada
	var cam_pivot := Node3D.new()
	add_child(cam_pivot)
	cam_pivot.global_position = (start_pos + meeting_point) * 0.5 + Vector3(0, td.cam_pivot_height, 0)

	# ── 1. Se miran — cámara al centro ───────────────────────────────────────
	cam.target = cam_pivot
	youn.play_anim("idle")
	player.set_anim_base("idle")
	_face_toward(youn, start_pos)
	_face_toward(player, meeting_point)
	await get_tree().create_timer(1.0).timeout

	# ── 2. Youn va al baño — jugador lo sigue con la mirada ──────────────────
	cam.target = youn
	youn.play_anim("walk")
	_face_toward(youn, entrance_pos)
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(youn, "global_position", entrance_pos, 1.0)
	var rot_start  := player.rotation.y
	var rot_target := _scene3d.yaw_toward(start_pos, toilet_pos)
	tw.parallel().tween_method(
		func(t: float): player.rotation.y = lerp_angle(rot_start, rot_target, t),
		0.0, 1.0, 0.8)
	await tw.finished

	# Youn entra al cilindro mirando hacia él
	_face_toward(youn, toilet_pos)
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(youn, "global_position", toilet_pos, 0.5)
	await tw.finished
	youn.visible = false
	youn.play_anim("idle")

	# ── 3. Esperar adentro ────────────────────────────────────────────────────
	await get_tree().create_timer(td.wait_inside).timeout

	# ── 4. Youn sale y vuelve al meeting point ────────────────────────────────
	youn.global_position = entrance_pos
	youn.visible = true
	youn.play_anim("walk")
	cam.target = youn
	_face_toward(youn, meeting_point)
	tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(youn, "global_position", meeting_point, 1.0)
	await tw.finished
	youn.play_anim("idle")

	# ── 5. Se miran de nuevo — pausa ─────────────────────────────────────────
	cam.target = cam_pivot
	_face_toward(youn, start_pos)
	_face_toward(player, meeting_point)
	await get_tree().create_timer(0.8).timeout

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

	# Restaurar todo
	GlobalHUD.set_clock_paused(false)
	PartyManager.unfreeze_camera()
	PartyManager.unfreeze_actors()
	cam_pivot.queue_free()
	_running = false


## Igual que CutsceneScene3D.face(), pero sin tocar la rotación si ya está
## pegado al target (CutsceneScene3D.yaw_toward() devolvería 0 y lo haría
## mirar al frente del mundo en vez de dejarlo como está).
func _face_toward(node: Node3D, target: Vector3) -> void:
	var d: Vector3 = target - node.global_position
	d.y = 0.0
	if d.length() > 0.05:
		node.rotation.y = _scene3d.yaw_toward(node.global_position, target)


func _path_passes_near(from: Vector3, to: Vector3, obstacle: Vector3, radius: float) -> bool:
	var d := to - from
	d.y = 0.0
	var dist := d.length()
	if dist < 0.01:
		return false
	var dir := d / dist
	var obs := obstacle - from
	obs.y = 0.0
	var proj    := clampf(dir.dot(obs), 0.0, dist)
	var closest := from + dir * proj
	closest.y   = obstacle.y
	return closest.distance_to(obstacle) < radius
