class_name WorldYounAi
extends RefCounted

## Máquina de estados de movimiento de WorldYoun: idle/wander/notice/chase/
## return/flee. No sabe nada de diálogo, combate ni loot — solo lee la
## posición propia y la del jugador, y mueve a `host` seteando
## velocity/rotation. `host` es el WorldYoun dueño exclusivo de esta
## instancia (nadie más la toca, a diferencia de los "privados" de MapArea).

const FLEE_SPEED := 6.0
const FLEE_TIME := 1.0

enum State { WANDER, IDLE, NOTICE, CHASE, RETURN, FLEE }

## Se agotó el timer de fuga: el host puede soltar el loot y liberarse.
signal flee_finished

var host: WorldYoun
var state: State = State.IDLE
var origin: Vector3
var target: Vector3
var timer: float = 0.0
var notice_delay: float = 0.0
var flee_dir: Vector3 = Vector3.ZERO

func _init(p_host: WorldYoun) -> void:
	host = p_host
	origin = host.global_position
	target = origin

func tick(delta: float) -> void:
	timer -= delta
	match state:
		State.IDLE:   _tick_idle(delta)
		State.WANDER: _tick_wander(delta)
		State.NOTICE: _tick_notice(delta)
		State.CHASE:  _tick_chase(delta)
		State.RETURN: _tick_return(delta)
		State.FLEE:   _tick_flee(delta)

## Entrada normal de reposo, y la que usa el host para "congelar" la pose
## (diálogo, combate) sin importarle que reinicie el timer de idle.
func start_idle() -> void:
	_set_state(State.IDLE)
	timer = randf_range(host.youn_data.idle_time_min, host.youn_data.idle_time_max)

## El host ya desactivó touch/colisión antes de llamar esto.
func start_flee(from_position: Vector3) -> void:
	_set_state(State.FLEE)
	timer = FLEE_TIME
	flee_dir = (host.global_position - from_position) * Vector3(1, 0, 1)
	if flee_dir.length() < 0.01:
		flee_dir = Vector3(0, 0, -1)
	else:
		flee_dir = flee_dir.normalized()

func _wander_radius() -> float:
	return host.wander_radius_override if host.wander_radius_override >= 0.0 else host.youn_data.wander_radius

func _detect_range() -> float:
	return host.detect_range_override if host.detect_range_override >= 0.0 else host.youn_data.detect_range

func _start_wander() -> void:
	_set_state(State.WANDER)
	var angle := randf() * TAU
	var radius := randf_range(2.0, _wander_radius())
	target = origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	timer = 4.0

func _start_notice() -> void:
	_set_state(State.NOTICE)
	notice_delay = randf_range(host.youn_data.notice_delay_min, host.youn_data.notice_delay_max)

func _start_return() -> void:
	_set_state(State.RETURN)
	target = origin

func _set_state(s: State) -> void:
	state = s
	match s:
		State.IDLE, State.NOTICE:
			host.switch_anim("idle")
		State.WANDER, State.RETURN:
			host.switch_anim("walk")
		State.CHASE, State.FLEE:
			host.switch_anim("run")

func _tick_idle(delta: float) -> void:
	host.velocity.x = 0.0
	host.velocity.z = 0.0
	if host.requires_interact and host.is_interaction_near() and host.player() != null:
		var to_player := host.player().global_position - host.global_position
		to_player.y = 0.0
		if to_player.length() > 0.01:
			host.rotation.y = lerp_angle(host.rotation.y, atan2(to_player.x, to_player.z), host.youn_data.rotate_speed * delta)
		return
	if _is_outside_leash():
		_start_return()
	elif _can_see_player():
		_start_notice()
	elif timer <= 0.0:
		if _wander_radius() > 0.0:
			_start_wander()
		else:
			start_idle()

func _tick_wander(delta: float) -> void:
	if _is_outside_leash():
		_start_return()
		return
	if _can_see_player():
		_start_notice()
		return
	var flat := Vector3(target.x, host.global_position.y, target.z)
	var diff := flat - host.global_position
	if diff.length() < 0.4 or timer <= 0.0:
		start_idle()
		return
	var dir := diff.normalized()
	host.velocity.x = dir.x * host.youn_data.wander_speed
	host.velocity.z = dir.z * host.youn_data.wander_speed
	_face_dir(dir, delta)

func _tick_notice(delta: float) -> void:
	host.velocity.x = 0.0
	host.velocity.z = 0.0
	if _is_outside_leash():
		_start_return()
		return
	if host.player() != null:
		var to_player := host.player().global_position - host.global_position
		to_player.y = 0.0
		if to_player.length() > 0.01:
			_face_dir(to_player.normalized(), delta * 3.0)
	if not _can_see_player(host.youn_data.lose_range):
		start_idle()
		return
	notice_delay -= delta
	if notice_delay <= 0.0:
		_set_state(State.CHASE)

func _tick_chase(delta: float) -> void:
	if host.player() == null:
		start_idle()
		return
	if _is_outside_leash():
		_start_return()
		return
	var to_player := host.player().global_position - host.global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > host.youn_data.lose_range:
		start_idle()
		return
	if dist < 0.8:
		host.velocity.x = 0.0
		host.velocity.z = 0.0
		return
	var dir := to_player.normalized()
	host.velocity.x = dir.x * host.youn_data.chase_speed * randf_range(0.9, 1.05)
	host.velocity.z = dir.z * host.youn_data.chase_speed * randf_range(0.9, 1.05)
	_face_dir(dir, delta)

func _tick_return(delta: float) -> void:
	var flat_origin := Vector3(origin.x, host.global_position.y, origin.z)
	var diff := flat_origin - host.global_position
	if diff.length() < 0.4:
		host.global_position.x = origin.x
		host.global_position.z = origin.z
		start_idle()
		return
	if _can_see_player() and not _is_outside_leash(0.85):
		_start_notice()
		return
	var dir := diff.normalized()
	host.velocity.x = dir.x * host.youn_data.wander_speed
	host.velocity.z = dir.z * host.youn_data.wander_speed
	_face_dir(dir, delta)

func _tick_flee(delta: float) -> void:
	host.velocity.x = flee_dir.x * FLEE_SPEED
	host.velocity.z = flee_dir.z * FLEE_SPEED
	_face_dir(flee_dir, delta)
	if timer <= 0.0:
		flee_finished.emit()

func _can_see_player(range_override := -1.0) -> bool:
	if host.player() == null:
		return false
	var dist := _detect_range() if range_override < 0.0 else range_override
	return host.player().global_position.distance_to(host.global_position) <= dist

func _is_outside_leash(buffer := 1.0) -> bool:
	return host.global_position.distance_to(origin) > host.youn_data.leash_range * buffer

func _face_dir(dir: Vector3, delta: float) -> void:
	host.rotation.y = lerp_angle(host.rotation.y, atan2(dir.x, dir.z), host.youn_data.rotate_speed * delta)
