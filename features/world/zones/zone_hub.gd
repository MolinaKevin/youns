extends Node3D

@export var toilet_data: ToiletData

var zone_id := "hub"
var _near_demo_monzaemon := false
var _bathroom_sequence_running := false
var _youn_in_toilet_area := false

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	$DemoMonzaemon/InteractArea.body_entered.connect(_on_demo_monzaemon_entered)
	$DemoMonzaemon/InteractArea.body_exited.connect(_on_demo_monzaemon_exited)
	$Toilet/ToiletArea.body_entered.connect(_on_toilet_area_entered)
	$Toilet/ToiletArea.body_exited.connect(_on_toilet_area_exited)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	LocalizationState.language_changed.connect(_apply_localized_text)
	_build_floor_collision()
	_fix_map_vertex_colors()
	_apply_localized_text()
	_refresh_demo_bridge_visibility()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_zone(zone_id)

func _on_lab_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_interior("res://features/world/lab_interior/lab_interior.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _is_cancel_pressed(event) and $DemoDialog.visible:
		get_viewport().set_input_as_handled()
		_set_demo_dialog_visible(false)
		return
	if _near_demo_monzaemon and _is_interact_pressed(event):
		get_viewport().set_input_as_handled()
		_set_demo_dialog_visible(true)

func _on_demo_monzaemon_entered(body: Node3D) -> void:
	if body.name != "Player" or not $DemoRamp.visible:
		return
	_near_demo_monzaemon = true
	$DemoMonzaemon/Prompt.visible = true

func _on_demo_monzaemon_exited(body: Node3D) -> void:
	if body.name != "Player":
		return
	_near_demo_monzaemon = false
	$DemoMonzaemon/Prompt.visible = false
	_set_demo_dialog_visible(false)

func _set_demo_dialog_visible(showing: bool) -> void:
	$DemoDialog.visible = showing
	$DemoMonzaemon/Prompt.visible = _near_demo_monzaemon and not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _on_recipe_completed(recipe: Resource) -> void:
	if recipe.id == "estudio_de_puente_ligero" or recipe.id == "construccion_de_puente":
		_refresh_demo_bridge_visibility()

func _refresh_demo_bridge_visibility() -> void:
	var bridge_researched := LaboratoryState.is_recipe_completed("estudio_de_puente_ligero") \
		or LaboratoryState.is_recipe_completed("construccion_de_puente")
	$DemoRamp.visible = bridge_researched
	$DemoMonzaemon.visible = bridge_researched
	if not bridge_researched:
		_near_demo_monzaemon = false
		_set_demo_dialog_visible(false)

func _is_cancel_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _is_interact_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("interact"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _fix_map_vertex_colors() -> void:
	var city_map := get_node_or_null("CityMap")
	if not city_map:
		return
	for node in city_map.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).vertex_color_use_as_albedo = true

func _build_floor_collision() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 0.1, 200)
	col.shape = shape
	col.position.y = -0.05
	body.add_child(col)
	add_child(body)

func _apply_localized_text(_language: String = "") -> void:
	$DemoMonzaemon/Prompt.text = LocalizationState.t("world.prompt.talk")
	$DemoDialog/Panel/Margin/Text.text = LocalizationState.t("world.demo.monzaemon")


# ── Secuencia del baño ────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _youn_in_toilet_area:
		_try_bathroom_sequence()


func _on_toilet_area_entered(body: Node3D) -> void:
	if body == PartyManager.youn:
		_youn_in_toilet_area = true
		_try_bathroom_sequence()


func _on_toilet_area_exited(body: Node3D) -> void:
	if body == PartyManager.youn:
		_youn_in_toilet_area = false


func _try_bathroom_sequence() -> void:
	if _bathroom_sequence_running:
		return
	var ps := GameState.player_save
	if ps == null or not ps.needs_bathroom:
		return
	_run_bathroom_sequence()


func _run_bathroom_sequence() -> void:
	_bathroom_sequence_running = true
	var player := PartyManager.player
	var youn   := PartyManager.youn
	var cam    := PartyManager.camera_rig

	# Resolver necesidad inmediatamente
	var ps := GameState.player_save
	if ps != null:
		ps.needs_bathroom = false
		ps.ganas_bano = 0
		ps.bathroom_need_since_total_hour = -1.0

	# Freezar controles y reloj
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	youn.set_physics_process(false)
	youn.velocity = Vector3.ZERO
	cam.enabled = false
	GameState.set_clock_paused(true)

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

	# ── 0. Player y Youn caminan lento al punto de arranque ──────────────────
	var youn_start := youn.global_position
	var y_to_p    := Vector3(youn_start.x - start_pos.x, 0.0, youn_start.z - start_pos.z)
	var side_dir  := perp if perp.dot(y_to_p) >= 0.0 else -perp
	var bypass_pt := Vector3(start_pos.x + side_dir.x * 1.5, youn_y, start_pos.z + side_dir.z * 1.5)

	youn.play_anim("walk")
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
	var rot_target := _angle_toward(start_pos, toilet_pos)
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
	GameState.set_clock_paused(false)
	cam.enabled = true
	player.set_physics_process(true)
	youn.set_physics_process(true)
	cam_pivot.queue_free()
	_bathroom_sequence_running = false


func _face_toward(node: Node3D, target: Vector3) -> void:
	var d: Vector3 = target - node.global_position
	d.y = 0.0
	if d.length() > 0.05:
		node.rotation.y = atan2(d.x, d.z)


func _angle_toward(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	d.y = 0.0
	return atan2(d.x, d.z) if d.length() > 0.05 else 0.0


func _path_passes_near(from: Vector3, to: Vector3, obstacle: Vector3, radius: float) -> bool:
	var d := to - from
	d.y = 0.0
	var len := d.length()
	if len < 0.01:
		return false
	var dir := d / len
	var obs := obstacle - from
	obs.y = 0.0
	var proj    := clampf(dir.dot(obs), 0.0, len)
	var closest := from + dir * proj
	closest.y   = obstacle.y
	return closest.distance_to(obstacle) < radius
