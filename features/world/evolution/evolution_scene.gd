class_name EvolutionScene
extends Node3D

signal finished
signal approach_finished

const ORBIT_DISTANCE := 2.5
const LOOK_AT_HEIGHT := 0.5
const Y_FLOAT        := 0.5

var _camera: Camera3D
var _youn_holder: Node3D
var _overlay: ColorRect
var _current_model: Node3D = null
var _approach_angle: float = 0.0


func _ready() -> void:
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


func start(from_data: YounData, to_data: YounData, from_cam_transform: Transform3D) -> void:
	var youn_node = PartyManager.youn if PartyManager else null
	var youn_r: float = youn_node.global_rotation.y if youn_node else 0.0
	var mesh_off: float = from_data.mesh_rotation_y if from_data else 0.0
	_approach_angle = 5.0 * PI / 4.0 - youn_r - mesh_off
	_camera.global_transform = from_cam_transform
	_camera.current = true
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

	# ── 2. Fondo se desvanece a negro — Youn del juego sigue visible ─────────
	approach_finished.emit()
	await get_tree().create_timer(0.5).timeout

	# ── 3. Pausa ─────────────────────────────────────────────────────────────
	await get_tree().create_timer(0.6).timeout

	# ── 4. Orbit 360° con el Youn actual ─────────────────────────────────────
	await _orbit(_approach_angle, _approach_angle + TAU, 6.0)

	# ── 5. Flash a blanco ────────────────────────────────────────────────────
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "color", Color(1, 1, 1, 1), 0.4)
	await tw.finished

	# ── 6. Swap: ocultar party y cargar nuevo Youn ────────────────────────────
	if PartyManager:
		PartyManager.set_party_visible(false)
	_load_model(to_data)
	_set_camera_angle(_approach_angle, ORBIT_DISTANCE)
	await get_tree().create_timer(0.15).timeout

	# ── 7. Revelar nuevo Youn ────────────────────────────────────────────────
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "color", Color(1, 1, 1, 0), 0.7)
	await tw.finished

	# ── 8. Orbit 360° ────────────────────────────────────────────────────────
	await _orbit(0.0, TAU, 4.0)

	# ── 9. Flash final ───────────────────────────────────────────────────────
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "color", Color(1, 1, 1, 1), 0.4)
	await tw.finished

	finished.emit()


func _orbit(from_angle: float, to_angle: float, duration: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(a: float): _set_camera_angle(a, ORBIT_DISTANCE),
		from_angle, to_angle, duration)
	await tw.finished


func _set_camera_angle(angle: float, distance: float) -> void:
	_camera.position = Vector3(
		sin(angle) * distance,
		ORBIT_DISTANCE * 0.5,
		cos(angle) * distance
	)
	_camera.look_at(_youn_holder.global_position + Vector3(0, LOOK_AT_HEIGHT, 0), Vector3.UP)


func _load_model(data: YounData) -> void:
	if _current_model:
		_current_model.queue_free()
		_current_model = null
	if data == null or data.scene_idle == null:
		return
	_current_model = data.scene_idle.instantiate()
	_current_model.scale = Vector3.ONE * data.mesh_scale
	_current_model.position.y = data.mesh_y_offset
	_current_model.rotation.y = data.mesh_rotation_y
	if data.texture:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mesh in _find_meshes(_current_model):
			mesh.material_override = mat
	_youn_holder.add_child(_current_model)


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result
