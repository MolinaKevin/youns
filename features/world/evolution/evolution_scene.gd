class_name EvolutionScene
extends Node3D

signal finished
signal approach_finished

const PlaceholderModel := preload("res://features/world/party/placeholder_model.gd")
const ORBIT_DISTANCE := 2.5
const LOOK_AT_HEIGHT := 0.5
const Y_FLOAT        := 0.5

var _camera: Camera3D
var _youn_holder: Node3D
var _overlay: ColorRect
var _current_model: Node3D = null
var _approach_angle: float = 0.0
var _flow: AsyncFlowToken
var _world_lighting: WorldLighting
var _saved_environment: Environment


func _ready() -> void:
	_flow = AsyncFlowToken.new(self)
	_build_scene()


func _build_scene() -> void:
	_youn_holder = Node3D.new()
	add_child(_youn_holder)

	_camera = Camera3D.new()
	_camera.current = false
	add_child(_camera)

	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_overlay)


func start(from_data: YounData, to_data: YounData, from_cam_transform: Transform3D, world_lighting: WorldLighting) -> void:
	if not _flow.is_active():
		return
	var youn_node = PartyManager.youn if PartyManager else null
	var youn_r: float = youn_node.global_rotation.y if youn_node else 0.0
	var mesh_off: float = from_data.mesh_rotation_y if from_data else 0.0
	_approach_angle = 5.0 * PI / 4.0 - youn_r - mesh_off
	_camera.global_transform = from_cam_transform
	_camera.current = true
	_world_lighting = world_lighting
	_run_sequence(to_data)


func _run_sequence(to_data: YounData) -> void:
	var tw: Tween

	# ── 1. Cámara vuela hacia el Youn (mundo visible) ────────────────────────
	var look_target := _youn_holder.global_position + Vector3(0, LOOK_AT_HEIGHT, 0)
	var from_pos    := _camera.global_position
	var target_pos  := _youn_holder.global_position + Vector3(
		sin(_approach_angle) * ORBIT_DISTANCE,
		ORBIT_DISTANCE * 0.5,
		cos(_approach_angle) * ORBIT_DISTANCE
	)
	var fly_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly_tw.tween_method(func(t: float):
		_camera.global_position = from_pos.lerp(target_pos, t)
		_camera.look_at(look_target, Vector3.UP)
	, 0.0, 1.0, 4.5)
	await fly_tw.finished
	if not _flow.is_active():
		return

	# ── 2. Fondo se desvanece a negro — Youn del juego sigue visible ─────────
	approach_finished.emit()
	if not _flow.is_active():
		return
	_enter_closeup_lighting()
	await get_tree().create_timer(0.5).timeout
	if not _flow.is_active():
		return

	# ── 3. Pausa ─────────────────────────────────────────────────────────────
	await get_tree().create_timer(0.6).timeout
	if not _flow.is_active():
		return

	# ── 4. Orbit 360° con el Youn actual ─────────────────────────────────────
	await _orbit(_approach_angle, _approach_angle + TAU, 6.0)
	if not _flow.is_active():
		return

	# ── 5. Flash a blanco ────────────────────────────────────────────────────
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "color", Color(1, 1, 1, 1), 0.4)
	await tw.finished
	if not _flow.is_active():
		return

	# ── 6. Swap: ocultar party y cargar nuevo Youn ────────────────────────────
	if PartyManager:
		PartyManager.set_party_visible(false)
	_load_model(to_data)
	_set_camera_angle(_approach_angle, ORBIT_DISTANCE)
	await get_tree().create_timer(0.15).timeout
	if not _flow.is_active():
		return

	# ── 7. Revelar nuevo Youn ────────────────────────────────────────────────
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "color", Color(1, 1, 1, 0), 0.7)
	await tw.finished
	if not _flow.is_active():
		return

	# ── 8. Orbit 360° ────────────────────────────────────────────────────────
	await _orbit(0.0, TAU, 4.0)
	if not _flow.is_active():
		return

	# ── 9. Flash final ───────────────────────────────────────────────────────
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "color", Color(1, 1, 1, 1), 0.4)
	await tw.finished
	if not _flow.is_active():
		return

	_restore_lighting()
	finished.emit()


## Apaga el sol, pone fondo negro con fundido y frena la transición de
## iluminación del mundo — restaurado en _restore_lighting() o, si la escena
## se destruye a mitad de la cinemática, en _exit_tree().
func _enter_closeup_lighting() -> void:
	if not is_instance_valid(_world_lighting):
		return
	_world_lighting.freeze_transition()
	_saved_environment = _world_lighting.world_env.environment
	_world_lighting.sun.light_energy = 4.0
	_world_lighting.sun.light_color = Color(1.0, 0.95, 0.9)
	_world_lighting.sun.shadow_enabled = false
	_world_lighting.fill.light_energy = 2.5
	_world_lighting.fill.light_color = Color(0.85, 0.9, 1.0)
	var black_env := Environment.new()
	black_env.background_mode = Environment.BG_COLOR
	black_env.background_color = _saved_environment.background_color
	black_env.fog_enabled = false
	black_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	black_env.ambient_light_color = Color(1.0, 1.0, 1.0)
	black_env.ambient_light_energy = 1.0
	_world_lighting.world_env.environment = black_env
	var bg_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	bg_tw.tween_property(black_env, "background_color", Color.BLACK, 0.5)


func _restore_lighting() -> void:
	if _saved_environment == null:
		return
	if is_instance_valid(_world_lighting):
		_world_lighting.world_env.environment = _saved_environment
		_world_lighting.reapply_current_period()
	_saved_environment = null


func _orbit(from_angle: float, to_angle: float, duration: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(a: float): _set_camera_angle(a, ORBIT_DISTANCE),
		from_angle, to_angle, duration)
	await tw.finished
	if not _flow.is_active():
		return


func _set_camera_angle(angle: float, distance: float) -> void:
	_camera.position = Vector3(
		sin(angle) * distance,
		ORBIT_DISTANCE * 0.5,
		cos(angle) * distance
	)
	_camera.look_at(_youn_holder.global_position + Vector3(0, LOOK_AT_HEIGHT, 0), Vector3.UP)


func _exit_tree() -> void:
	if _flow != null:
		_flow.cancel()
	# La escena puede desaparecer a mitad del flash, después de ocultar el
	# grupo. Restaurarlo acá hace que una transición de escena no herede ese
	# detalle visual.
	if PartyManager:
		PartyManager.set_party_visible(true)
	# Idem para la iluminación: si la cinemática ya tomó control manual del
	# sol/fondo cuando la escena se destruye, no queda tomado para siempre.
	_restore_lighting()


func _load_model(data: YounData) -> void:
	if _current_model:
		_current_model.queue_free()
		_current_model = null
	if data == null:
		return
	if data.scene_idle == null:
		# Sin modelo todavía: el provisorio de primitivas.
		_current_model = PlaceholderModel.build(data)
		_youn_holder.add_child(_current_model)
		return
	_current_model = data.scene_idle.instantiate()
	_current_model.scale = Vector3.ONE * data.mesh_scale
	_current_model.position.y = data.mesh_y_offset
	_current_model.rotation.y = data.mesh_rotation_y
	if data.texture:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mesh in Node3DSearch.find_meshes(_current_model):
			mesh.material_override = mat
	_youn_holder.add_child(_current_model)
