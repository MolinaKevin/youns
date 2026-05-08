extends CharacterBody3D

const GRAVITY := 20.0

@export var youn_data: YounData

enum State { WANDER, IDLE, NOTICE, CHASE }

var _state: State = State.IDLE
var _player: CharacterBody3D
var _origin: Vector3
var _target: Vector3
var _timer: float = 0.0
var _notice_delay: float = 0.0
var _anim: AnimationPlayer = null
var _mat: StandardMaterial3D = null

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_origin = global_position
	_target = global_position
	if youn_data:
		_load_model(youn_data)
	_set_state(State.CHASE)

func load_youn(data: YounData) -> void:
	youn_data = data
	var old := get_node_or_null("Body")
	if old:
		old.queue_free()
	_anim = null
	_load_model(data)

func _load_model(data: YounData) -> void:
	var packed := data.scene_idle
	if not packed:
		return
	var body: Node3D = packed.instantiate()
	body.name = "Body"
	body.position = Vector3(0.0, data.mesh_y_offset, 0.0)
	body.scale = Vector3.ONE * data.mesh_scale
	add_child(body)

	if data.texture:
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = data.texture
		for mesh in _find_meshes(body):
			mesh.material_override = _mat

	_anim = _find_anim_player(body)
	if _anim:
		var list := _anim.get_animation_list()
		if not list.is_empty():
			_anim.play(list[0])

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_timer -= delta

	match _state:
		State.IDLE:   _tick_idle()
		State.WANDER: _tick_wander(delta)
		State.NOTICE: _tick_notice(delta)
		State.CHASE:  _tick_chase(delta)

	move_and_slide()

# ── State ticks ───────────────────────────────────────────────────────────────

func _tick_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _can_see_player():
		_start_notice()
		return
	if _timer <= 0.0:
		_start_wander()

func _tick_wander(delta: float) -> void:
	if _can_see_player():
		_start_notice()
		return
	var flat := Vector3(_target.x, global_position.y, _target.z)
	var diff := flat - global_position
	if diff.length() < 0.4 or _timer <= 0.0:
		_start_idle()
		return
	var dir := diff.normalized()
	velocity.x = dir.x * _wander_speed()
	velocity.z = dir.z * _wander_speed()
	_face_dir(dir, delta)
	_play("walk")

func _tick_notice(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _player:
		var to_player := (_player.global_position - global_position)
		to_player.y = 0.0
		if to_player.length() > 0.01:
			_face_dir(to_player.normalized(), delta * 3.0)
	_notice_delay -= delta
	if _notice_delay <= 0.0:
		_set_state(State.CHASE)

func _tick_chase(delta: float) -> void:
	if not _player:
		_start_idle()
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist < 0.6:
		velocity.x = 0.0
		velocity.z = 0.0
		_play("idle")
		return
	var dir := to_player.normalized()
	var speed := _chase_speed() * randf_range(0.9, 1.05)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_dir(dir, delta)
	_play("run")

# ── Transitions ───────────────────────────────────────────────────────────────

func _start_idle() -> void:
	_set_state(State.IDLE)
	_timer = randf_range(_idle_min(), _idle_max())
	_play("idle")

func _start_wander() -> void:
	_set_state(State.WANDER)
	var angle := randf() * TAU
	var radius := randf_range(2.0, _wander_radius())
	_target = _origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_timer = 4.0

func _start_notice() -> void:
	_set_state(State.NOTICE)
	_notice_delay = randf_range(_notice_min(), _notice_max())

func _set_state(s: State) -> void:
	_state = s

# ── Helpers ───────────────────────────────────────────────────────────────────

func _can_see_player() -> bool:
	if not _player:
		return false
	return _player.global_position.distance_to(global_position) <= _detect_range()

func _face_dir(dir: Vector3, delta: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, _rotate_speed() * delta)

func _play(anim_name: String) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name)

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

# ── YounData accessors (fallback a defaults si no hay data) ───────────────────

func _wander_speed()  -> float: return youn_data.wander_speed  if youn_data else 2.2
func _chase_speed()   -> float: return youn_data.chase_speed   if youn_data else 5.8
func _rotate_speed()  -> float: return youn_data.rotate_speed  if youn_data else 8.0
func _detect_range()  -> float: return youn_data.detect_range  if youn_data else 12.0
func _wander_radius() -> float: return youn_data.wander_radius if youn_data else 8.0
func _idle_min()      -> float: return youn_data.idle_time_min  if youn_data else 0.8
func _idle_max()      -> float: return youn_data.idle_time_max  if youn_data else 2.5
func _notice_min()    -> float: return youn_data.notice_delay_min if youn_data else 0.4
func _notice_max()    -> float: return youn_data.notice_delay_max if youn_data else 1.3
