extends CharacterBody3D

const GRAVITY := 20.0

enum State { WANDER, IDLE, NOTICE, CHASE }

@export var enemy_data: EnemyData

@onready var body_mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $Collision

var _state: State = State.IDLE
var _player: CharacterBody3D
var _origin: Vector3
var _target: Vector3
var _timer: float = 0.0
var _notice_delay: float = 0.0

func _ready() -> void:
	_player = PartyManager.player
	_origin = global_position
	_target = global_position
	_apply_enemy_data()
	_start_idle()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_timer -= delta

	match _state:
		State.IDLE:
			_tick_idle()
		State.WANDER:
			_tick_wander(delta)
		State.NOTICE:
			_tick_notice(delta)
		State.CHASE:
			_tick_chase(delta)

	move_and_slide()

func _apply_enemy_data() -> void:
	if enemy_data == null:
		return
	body_mesh.mesh = enemy_data.mesh
	body_mesh.position.y = enemy_data.mesh_y_offset
	body_mesh.scale = Vector3.ONE * enemy_data.mesh_scale

	var shape := CapsuleShape3D.new()
	shape.radius = enemy_data.collision_radius
	shape.height = enemy_data.collision_height
	collision.shape = shape

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
	velocity.x = dir.x * enemy_data.wander_speed
	velocity.z = dir.z * enemy_data.wander_speed
	_face_dir(dir, delta)

func _tick_notice(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if _player:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > 0.01:
			_face_dir(to_player.normalized(), delta * 3.0)

	if not _can_see_player(enemy_data.lose_range):
		_start_idle()
		return

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

	if dist > enemy_data.lose_range:
		_start_idle()
		return

	if dist < 0.8:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var dir := to_player.normalized()
	var speed := enemy_data.chase_speed * randf_range(0.9, 1.05)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_dir(dir, delta)

func _start_idle() -> void:
	_set_state(State.IDLE)
	_timer = randf_range(enemy_data.idle_time_min, enemy_data.idle_time_max)

func _start_wander() -> void:
	_set_state(State.WANDER)
	var angle := randf() * TAU
	var radius := randf_range(2.0, enemy_data.wander_radius)
	_target = _origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_timer = 4.0

func _start_notice() -> void:
	_set_state(State.NOTICE)
	_notice_delay = randf_range(enemy_data.notice_delay_min, enemy_data.notice_delay_max)

func _set_state(state: State) -> void:
	_state = state

func _can_see_player(range_override := -1.0) -> bool:
	if _player == null:
		return false
	var range := enemy_data.detect_range if range_override < 0.0 else range_override
	return _player.global_position.distance_to(global_position) <= range

func _face_dir(dir: Vector3, delta: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, enemy_data.rotate_speed * delta)
