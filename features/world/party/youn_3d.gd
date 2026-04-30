extends CharacterBody3D

const GRAVITY        := 20.0
const FOLLOW_DIST    := 2.0
const STOP_DIST      := 1.2

@export var youn_data: YounData

var _player: CharacterBody3D
var _anim: AnimationPlayer = null
var _idle_timer: float = 0.0
var _body_rig: Node3D = null
var _body_idle: Node3D = null

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	if youn_data:
		_load_model(youn_data)

func load_youn(data: YounData) -> void:
	youn_data = data
	var old := get_node_or_null("Body")
	if old:
		old.queue_free()
	_anim = null
	_load_model(data)

func _load_model(data: YounData) -> void:
	if not data.scene:
		return

	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_body_rig = data.scene.instantiate()
	_body_rig.name = "BodyRig"
	_body_rig.scale = Vector3.ONE * data.mesh_scale
	_body_rig.position.y = data.mesh_y_offset
	add_child(_body_rig)
	if mat:
		for mesh in _find_meshes(_body_rig):
			mesh.material_override = mat

	if data.idle_scene:
		_body_idle = data.idle_scene.instantiate()
		_body_idle.name = "BodyIdle"
		_body_idle.scale = Vector3.ONE * data.mesh_scale
		_body_idle.position.y = data.mesh_y_offset
		_body_idle.visible = false
		add_child(_body_idle)
		if mat:
			for mesh in _find_meshes(_body_idle):
				mesh.material_override = mat
		_anim = _find_anim_player(_body_idle)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if not _player:
		move_and_slide()
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > FOLLOW_DIST:
		_set_idle_pose(false)
		_idle_timer = 0.0
		var dir := to_player.normalized()
		var speed := youn_data.chase_speed if youn_data else 5.8
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_dir(dir, delta)
	elif dist > STOP_DIST:
		_set_idle_pose(false)
		_idle_timer = 0.0
		var dir := to_player.normalized()
		var speed := (youn_data.wander_speed if youn_data else 2.2) * (dist / FOLLOW_DIST)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_dir(dir, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_idle_timer += delta
		if _idle_timer >= 3.0:
			_set_idle_pose(true)

	move_and_slide()

func _set_idle_pose(active: bool) -> void:
	if _body_rig:
		_body_rig.visible = not active
	if _body_idle:
		_body_idle.visible = active
		if active:
			_play(youn_data.anim_idle if youn_data else "idle")

func _face_dir(dir: Vector3, delta: float) -> void:
	var rotate_speed := youn_data.rotate_speed if youn_data else 8.0
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, rotate_speed * delta)

func _play(anim_name: String) -> void:
	if not _anim:
		return
	var target := anim_name
	if not _anim.has_animation(target):
		var list := _anim.get_animation_list()
		if list.is_empty():
			return
		target = list[0]
	if _anim.current_animation != target:
		_anim.play(target)

func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_meshes(child))
	return result

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null
