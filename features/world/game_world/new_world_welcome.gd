class_name NewWorldWelcome
extends Node3D

## Segunda mitad de la apertura: ya dentro del hub, presenta al jugador el
## mundo con un fundido desde negro y una pequeña ronda ceremonial de Youns.

const NarrativeYouns := preload("res://data/youns/narrative_youn_catalog.gd")
const PACHAMAMA_PATH := NarrativeYouns.PACHAMAMA
const YounOrientationScript := preload("res://shared/youn_orientation.gd")
const DebugLog := preload("res://shared/debug_logging.gd")
const GUEST_PATHS := NarrativeYouns.WELCOME_GUESTS
const RING_RADIUS := 5.5

signal finished

var _overlay: ColorRect
var _camera: Camera3D
var _guests := Node3D.new()
var _pachamama_model: Node3D
var _center := Vector3.ZERO
var _flow: AsyncFlowToken


func start() -> void:
	_flow = AsyncFlowToken.new(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "NewWorldWelcome"
	_log("Iniciando bienvenida al mundo.")
	add_child(_guests)
	# El filtro global normal vive en la capa base. Esta copia temporal queda
	# justo debajo del fundido y asegura el mismo look PS1 con la cámara propia
	# de la ronda ceremonial.
	Ps1ScreenFx.attach(self, 79)
	PartyManager.freeze_actors()
	PartyManager.freeze_camera()
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_youns_status_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_black_overlay()
	await get_tree().process_frame
	if not _flow.is_active(): return
	_center = PartyManager.player.global_position
	# El jugador queda en el centro mirando hacia Pachamama (las 12). No se
	# teletransporta ni se vuelve a colocar en ningún momento de la ceremonia.
	PartyManager.player.rotation.y = PI
	_prepare_companion_arrival()
	_build_cinematic_camera(_center)
	_build_guests(_center)
	_log("Ronda ceremonial construida; revelando el mundo.")
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(_overlay, "color:a", 0.0, 2.0)
	await fade.finished
	if not _flow.is_active(): return
	await _pachamama_arrives()
	if not _flow.is_active(): return
	_log("Pachamama llegó; comienza el diálogo.")
	await _speak()
	if not _flow.is_active(): return
	_finish()


func _build_black_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArrivalFadeLayer"
	layer.layer = 80
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color.BLACK
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)


func _build_cinematic_camera(center: Vector3) -> void:
	_camera = Camera3D.new()
	_camera.position = center + Vector3(0.0, 3.8, 9.6)
	_camera.fov = 44.0
	add_child(_camera)
	_camera.look_at(center + Vector3(0.0, 1.0, -0.8), Vector3.UP)
	_camera.make_current()


func _build_guests(center: Vector3) -> void:
	var pachamama := NarrativeYouns.pachamama()
	if pachamama != null:
		_pachamama_model = _add_model(pachamama, center + Vector3(0.0, 0.0, -10.0), center, pachamama.scene_walk)
	for index in GUEST_PATHS.size():
		var data := NarrativeYouns.youn(GUEST_PATHS[index])
		if data == null:
			continue
		var save := PlayerSessionAccess.save()
		if save != null and data.resource_path == save.current_youn_path:
			continue
		var angle := TAU * float(index) / float(GUEST_PATHS.size())
		var guest_position := center + Vector3(sin(angle) * RING_RADIUS, 0.0, -2.3 - cos(angle) * RING_RADIUS)
		_add_model(data, guest_position, center)


func _add_model(data: YounData, world_position: Vector3, look_target: Vector3, scene_override: PackedScene = null) -> Node3D:
	var scene := scene_override if scene_override != null else data.scene_idle if data.scene_idle != null else data.scene_walk
	var model := _instantiate_model(data, scene)
	if model == null:
		return null
	model.position = world_position + Vector3(0.0, data.mesh_y_offset, 0.0)
	_guests.add_child(model)
	YounOrientationScript.face_target(model, look_target, data)
	return model


func _instantiate_model(data: YounData, scene: PackedScene) -> Node3D:
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	model.scale = Vector3.ONE * data.mesh_scale * 1.2
	if data.texture != null:
		var material := StandardMaterial3D.new()
		material.albedo_texture = data.texture
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mesh in Node3DSearch.find_meshes(model):
			mesh.material_override = material
	var animation_player := Node3DSearch.find_anim_player(model)
	if animation_player != null:
		var animations := animation_player.get_animation_list()
		if not animations.is_empty():
			var animation := animation_player.get_animation(animations[0])
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(animations[0])
	return model


func _prepare_companion_arrival() -> void:
	if not is_instance_valid(PartyManager.youn):
		return
	# El compañero real está desde el inicio a las 6, detrás del jugador. No se
	# crea un doble ni se usa place_at: luego sólo se anima este mismo nodo.
	PartyManager.youn.global_position = _center + Vector3(0.0, 0.0, 5.4)
	PartyManager.youn.visible = true


func _pachamama_arrives() -> void:
	if _pachamama_model == null:
		return
	var arrival := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	arrival.tween_property(_pachamama_model, "global_position", _center + Vector3(0.0, 0.0, -3.2), 3.8)
	await arrival.finished
	if not _flow.is_active(): return
	_replace_pachamama_with_idle()


func _replace_pachamama_with_idle() -> void:
	if _pachamama_model == null:
		return
	var data := NarrativeYouns.pachamama()
	if data == null or data.scene_idle == null:
		return
	var idle_model := _instantiate_model(data, data.scene_idle)
	if idle_model == null:
		return
	var arrival_transform := _pachamama_model.global_transform
	_guests.add_child(idle_model)
	idle_model.global_transform = arrival_transform
	_pachamama_model.queue_free()
	_pachamama_model = idle_model


func _companion_arrives() -> void:
	if not is_instance_valid(PartyManager.youn):
		return
	var companion := PartyManager.youn
	var direction := _center - companion.global_position
	direction.y = 0.0
	# Misma convención que YounFollowMovement._face_dir(): el cuerpo del Youn
	# aplica después su propio mesh_rotation_y (Nguruvilu incluido).
	if direction.length_squared() > 0.01:
		companion.rotation.y = atan2(direction.x, direction.z)
	companion.play_anim("walk")
	var arrival := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Las 6: queda centrado abajo del jugador, no al costado (las 5).
	arrival.tween_property(companion, "global_position", _center + Vector3(0.0, 0.0, 1.7), 2.8)
	await arrival.finished
	if not _flow.is_active(): return
	companion.play_anim("idle")


func _turn_player_toward(rotation_y: float) -> void:
	if not is_instance_valid(PartyManager.player):
		return
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(PartyManager.player, "rotation:y", rotation_y, 0.65)
	await turn.finished
	if not _flow.is_active(): return


func _speak() -> void:
	var pachamama := NarrativeYouns.pachamama()
	if pachamama == null:
		return
	var save := PlayerSessionAccess.save()
	var player_name := save.player_name if save != null else LocalizationState.t("welcome.player_fallback")
	DialogueLines.say_many(pachamama, [
		LocalizationState.t("welcome.look_around", [player_name]),
		LocalizationState.t("welcome.every_youn"),
	])
	await Dialogue.dialogue_finished
	if not _flow.is_active(): return
	var companion_name := save.companion_name if save != null else LocalizationState.t("welcome.companion_fallback")
	DialogueLines.say_many(pachamama, [LocalizationState.t("welcome.introduce_companion", [companion_name])])
	await Dialogue.dialogue_finished
	if not _flow.is_active(): return
	await _turn_player_toward(0.0)
	await _companion_arrives()
	await _turn_player_toward(PI)
	DialogueLines.say_many(pachamama, [LocalizationState.t("welcome.care_together")])
	await Dialogue.dialogue_finished
	if not _flow.is_active(): return
	await _fade_guests_away()


func _fade_guests_away() -> void:
	_log("Fundido de cierre; retirando la ronda ceremonial.")
	var to_black := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	to_black.tween_property(_overlay, "color:a", 1.0, 0.65)
	await to_black.finished
	if not _flow.is_active(): return
	_guests.queue_free()
	await get_tree().process_frame
	if not _flow.is_active(): return
	var from_black := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	from_black.tween_property(_overlay, "color:a", 0.0, 0.8)
	await from_black.finished
	if not _flow.is_active(): return


func _finish() -> void:
	_log("Bienvenida terminada; conservando plano para el tutorial.")
	GameState.new_game_ceremony_completed = false
	# El jugador sigue exactamente donde quedó. Se restablecen físicas para que
	# apoye en el suelo, pero la cámara cinematográfica se conserva hasta que el
	# usuario cierre el tutorial; así no hay un salto visual al spawn antiguo.
	PartyManager.unfreeze_actors()
	finished.emit()


func restore_gameplay_camera() -> void:
	_log("Tutorial cerrado; devolviendo cámara y control.")
	PartyManager.unfreeze_camera()
	if is_instance_valid(PartyManager.camera_rig):
		var world_camera := PartyManager.camera_rig.get_node_or_null("Camera3D") as Camera3D
		if world_camera != null:
			world_camera.make_current()
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _exit_tree() -> void:
	if _flow != null:
		_flow.cancel()
	# Una salida forzada (carga, combate o cierre) no puede dejar la party ni
	# las capas persistentes en el estado ceremonial.
	if is_instance_valid(PartyManager):
		PartyManager.unfreeze_actors()
		PartyManager.unfreeze_camera()
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())


func _log(message: String) -> void:
	if DebugLog.verbose_enabled():
		print("[NewWorldWelcome] %s" % message)
