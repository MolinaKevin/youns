extends CharacterBody3D

const GRAVITY        := 20.0
const WANDER_SPEED   := 2.2
const CHASE_SPEED    := 5.8
const ROTATE_SPEED   := 8.0
const DETECT_RANGE   := 12.0
const LOSE_RANGE     := 18.0
const WANDER_RADIUS  := 8.0

enum State { WANDER, IDLE, NOTICE, CHASE }

var _state: State = State.IDLE
var _player: CharacterBody3D
var _origin: Vector3
var _target: Vector3
var _timer: float = 0.0
var _notice_delay: float = 0.0

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_origin = global_position
	_target = global_position
	_set_state(State.CHASE)

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

# ── State ticks ──────────────────────────────────────────────────────────────

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
	velocity.x = dir.x * WANDER_SPEED
	velocity.z = dir.z * WANDER_SPEED
	_face_dir(dir, delta)

func _tick_notice(delta: float) -> void:
	# Freeze, face player, wait before chasing
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
		return

	var dir := to_player.normalized()
	# Slight speed variation to feel organic
	var speed := CHASE_SPEED * randf_range(0.9, 1.05)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face_dir(dir, delta)

# ── Transitions ───────────────────────────────────────────────────────────────

func _start_idle() -> void:
	_set_state(State.IDLE)
	_timer = randf_range(0.8, 2.5)

func _start_wander() -> void:
	_set_state(State.WANDER)
	var angle := randf() * TAU
	var radius := randf_range(2.0, WANDER_RADIUS)
	_target = _origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_timer = 4.0

func _start_notice() -> void:
	_set_state(State.NOTICE)
	_notice_delay = randf_range(0.4, 1.3)

func _set_state(s: State) -> void:
	_state = s

# ── Helpers ───────────────────────────────────────────────────────────────────

func _can_see_player() -> bool:
	if not _player:
		return false
	return _player.global_position.distance_to(global_position) <= DETECT_RANGE

func _face_dir(dir: Vector3, delta: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, ROTATE_SPEED * delta)
