extends CharacterBody3D

const GRAVITY := 20.0
const CONTACT_POPUP_TIME := 0.9
const FLEE_SPEED := 6.0
const FLEE_TIME := 1.0
const DROP_SCENE := preload("res://features/world/items/world_drop.tscn")

enum State { WANDER, IDLE, NOTICE, CHASE, RETURN, FLEE }

@export var enemy_data: EnemyData
@export var world_enemy_id := ""

@onready var body_mesh: MeshInstance3D = $Body
@onready var collision: CollisionShape3D = $Collision
@onready var touch_area: Area3D = $TouchArea
@onready var touch_shape: CollisionShape3D = $TouchArea/TouchCollision
@onready var popup_layer: CanvasLayer = $PopupLayer
@onready var popup_panel: Panel = $PopupLayer/Popup
@onready var popup_label: Label = $PopupLayer/Popup/Margin/Label

var _state: State = State.IDLE
var _player: CharacterBody3D
var _origin: Vector3
var _target: Vector3
var _timer: float = 0.0
var _notice_delay: float = 0.0
var _popup_timer: float = 0.0
var _engaging_combat := false
var _waiting_for_combat := false
var _flee_dir := Vector3.ZERO

func _ready() -> void:
	add_to_group("world_enemy")
	if world_enemy_id == "":
		world_enemy_id = name
	_player = PartyManager.player
	_apply_enemy_data()
	_snap_to_ground()
	_origin = global_position
	_target = global_position
	touch_area.body_entered.connect(_on_touch_area_body_entered)
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
		State.RETURN:
			_tick_return(delta)
		State.FLEE:
			_tick_flee(delta)

	move_and_slide()

	if _popup_timer > 0.0:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			popup_panel.visible = false

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
	collision.position.y = enemy_data.collision_height * 0.5

	var touch := SphereShape3D.new()
	touch.radius = enemy_data.collision_radius + 0.35
	touch_shape.shape = touch
	popup_label.text = LocalizationState.t(
		"world.enemy.intercepted",
		[LocalizationState.enemy_name(enemy_data.id, enemy_data.enemy_name)]
	)

func _tick_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if _is_outside_leash():
		_start_return()
		return

	if _can_see_player():
		_start_notice()
		return

	if _timer <= 0.0:
		_start_wander()

func _tick_wander(delta: float) -> void:
	if _is_outside_leash():
		_start_return()
		return

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

	if _is_outside_leash():
		_start_return()
		return

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

	if _is_outside_leash():
		_start_return()
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

func _tick_return(delta: float) -> void:
	var flat_origin := Vector3(_origin.x, global_position.y, _origin.z)
	var diff := flat_origin - global_position
	if diff.length() < 0.4:
		global_position.x = _origin.x
		global_position.z = _origin.z
		_start_idle()
		return

	if _can_see_player() and not _is_outside_leash(0.85):
		_start_notice()
		return

	var dir := diff.normalized()
	velocity.x = dir.x * enemy_data.wander_speed
	velocity.z = dir.z * enemy_data.wander_speed
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

func _start_return() -> void:
	_set_state(State.RETURN)
	_target = _origin

func _start_flee(from_position: Vector3) -> void:
	_engaging_combat = true
	touch_area.monitoring = false
	collision.disabled = true
	_set_state(State.FLEE)
	_timer = FLEE_TIME
	_flee_dir = global_position - from_position
	_flee_dir.y = 0.0
	if _flee_dir.length() < 0.01:
		_flee_dir = Vector3(0, 0, -1)
	else:
		_flee_dir = _flee_dir.normalized()

func _set_state(state: State) -> void:
	_state = state

func _can_see_player(range_override := -1.0) -> bool:
	if _player == null:
		return false
	var detect_distance := enemy_data.detect_range if range_override < 0.0 else range_override
	return _player.global_position.distance_to(global_position) <= detect_distance

func _is_outside_leash(buffer := 1.0) -> bool:
	var dist_from_spawn := global_position.distance_to(_origin)
	return dist_from_spawn > enemy_data.leash_range * buffer

func _face_dir(dir: Vector3, delta: float) -> void:
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, enemy_data.rotate_speed * delta)

func _tick_flee(delta: float) -> void:
	velocity.x = _flee_dir.x * FLEE_SPEED
	velocity.z = _flee_dir.z * FLEE_SPEED
	_face_dir(_flee_dir, delta)
	if _timer <= 0.0:
		_spawn_drop()
		queue_free()

func _snap_to_ground() -> void:
	var half_height := enemy_data.collision_height * 0.5
	var start := global_position + Vector3.UP * 8.0
	var finish := global_position + Vector3.DOWN * 24.0
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = hit.position.y + half_height

func _on_touch_area_body_entered(body: Node3D) -> void:
	if body != _player or _engaging_combat:
		return
	_engage_combat()

func _engage_combat() -> void:
	_engaging_combat = true
	_set_state(State.IDLE)
	velocity = Vector3.ZERO

	if _player:
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(false)
		var to_enemy := global_position - _player.global_position
		to_enemy.y = 0.0
		if to_enemy.length() > 0.01:
			_player.rotation.y = atan2(to_enemy.x, to_enemy.z)

	var to_player := Vector3.ZERO
	if _player:
		to_player = _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > 0.01:
			rotation.y = atan2(to_player.x, to_player.z)

	set_physics_process(false)
	popup_label.text = LocalizationState.t(
		"world.enemy.intercepted",
		[LocalizationState.enemy_name(enemy_data.id, enemy_data.enemy_name)]
	) + "\n" + LocalizationState.t("world.enemy.press_enter")
	popup_panel.visible = true
	_waiting_for_combat = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseMenu.enabled = false
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_for_combat:
		return
	if event.is_action_pressed("ui_accept"):
		_waiting_for_combat = false
		popup_panel.visible = false
		get_tree().paused = false
		process_mode = Node.PROCESS_MODE_PAUSABLE
		get_viewport().set_input_as_handled()
		_start_combat_transition()

func _start_combat_transition() -> void:
	GameState.combat_return_pending = true
	GameState.combat_return_position = _player.global_position if _player else global_position
	GameState.combat_world_enemy_id = world_enemy_id
	GameState.pending_enemy_data = enemy_data
	if GameState.player_save != null and "bathroom" in StatsManager.active_states:
		GameState.player_save.bathroom_pending_after_combat = true
	get_tree().change_scene_to_file("res://features/combat/scene/combat.tscn")

func handle_player_victory(return_position: Vector3) -> void:
	_player = PartyManager.player
	_engaging_combat = false
	set_physics_process(true)
	visible = true
	_start_flee(return_position)

func _spawn_drop() -> void:
	var drop := DROP_SCENE.instantiate()
	drop.position = global_position + Vector3(0, 0.2, 0)
	drop.item_name = enemy_data.loot_item_name
	drop.gold_amount = 0
	get_parent().add_child(drop)
