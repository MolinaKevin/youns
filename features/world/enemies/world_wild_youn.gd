extends CharacterBody3D

const GRAVITY := 20.0
const FLEE_SPEED := 6.0
const FLEE_TIME := 1.0
const DROP_SCENE := preload("res://features/world/items/world_drop.tscn")

enum State { WANDER, IDLE, NOTICE, CHASE, RETURN, FLEE }

@export var youn_data: YounData
@export var world_enemy_id := ""

@onready var body_root: Node3D = $Body
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
var _anim_bodies: Dictionary = {}
var _anim_current: String = ""

func _ready() -> void:
	add_to_group("world_enemy")
	if world_enemy_id == "":
		world_enemy_id = name
	_player = PartyManager.player
	_setup()
	_snap_to_ground()
	_origin = global_position
	_target = global_position
	touch_area.body_entered.connect(_on_touch_area_body_entered)
	_start_idle()

func _setup() -> void:
	if youn_data == null:
		return

	var mat: StandardMaterial3D = null
	if youn_data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = youn_data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for key in ["idle", "walk", "run"]:
		var packed: PackedScene = youn_data.get("scene_" + key)
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * youn_data.mesh_scale
		body.position.y = 0.0
		body.visible = false
		if mat:
			for mi in _find_meshes(body):
				mi.material_override = mat
		body_root.add_child(body)
		_anim_bodies[key] = body

	if _anim_bodies.is_empty() and youn_data.mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = youn_data.mesh
		mi.scale = Vector3.ONE * youn_data.mesh_scale
		mi.position.y = youn_data.mesh_y_offset  # offset estático sí aplica, es relativo al mesh origin
		if mat:
			mi.material_override = mat
		body_root.add_child(mi)
	else:
		_switch_anim("idle")

	var cap := CapsuleShape3D.new()
	cap.radius = youn_data.collision_radius
	cap.height = youn_data.collision_height
	collision.shape = cap
	collision.position.y = youn_data.collision_height * 0.5

	var sphere := SphereShape3D.new()
	sphere.radius = youn_data.collision_radius + 0.35
	touch_shape.shape = sphere

	popup_label.text = LocalizationState.t("world.enemy.intercepted", [youn_data.youn_name])

# ── Animations ────────────────────────────────────────────────────────────────

func _switch_anim(key: String) -> void:
	var target := key if key in _anim_bodies else "idle"
	if _anim_current == target:
		return
	if _anim_current in _anim_bodies:
		_anim_bodies[_anim_current].visible = false
	_anim_current = target
	if target not in _anim_bodies:
		return
	var body: Node3D = _anim_bodies[target]
	body.visible = true
	var ap := _find_anim_player(body)
	if ap:
		var list := ap.get_animation_list()
		if not list.is_empty():
			var anim := ap.get_animation(list[0])
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(list[0])

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

# ── Physics ───────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_timer -= delta
	match _state:
		State.IDLE:   _tick_idle()
		State.WANDER: _tick_wander(delta)
		State.NOTICE: _tick_notice(delta)
		State.CHASE:  _tick_chase(delta)
		State.RETURN: _tick_return(delta)
		State.FLEE:   _tick_flee(delta)
	move_and_slide()
	if _popup_timer > 0.0:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			popup_panel.visible = false

func _tick_idle() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _is_outside_leash():
		_start_return()
	elif _can_see_player():
		_start_notice()
	elif _timer <= 0.0:
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
	velocity.x = dir.x * youn_data.wander_speed
	velocity.z = dir.z * youn_data.wander_speed
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
	if not _can_see_player(youn_data.lose_range):
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
	if dist > youn_data.lose_range:
		_start_idle()
		return
	if dist < 0.8:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := to_player.normalized()
	velocity.x = dir.x * youn_data.chase_speed * randf_range(0.9, 1.05)
	velocity.z = dir.z * youn_data.chase_speed * randf_range(0.9, 1.05)
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
	velocity.x = dir.x * youn_data.wander_speed
	velocity.z = dir.z * youn_data.wander_speed
	_face_dir(dir, delta)

func _tick_flee(delta: float) -> void:
	velocity.x = _flee_dir.x * FLEE_SPEED
	velocity.z = _flee_dir.z * FLEE_SPEED
	_face_dir(_flee_dir, delta)
	if _timer <= 0.0:
		_spawn_drop()
		queue_free()

# ── State transitions ─────────────────────────────────────────────────────────

func _set_state(s: State) -> void:
	_state = s
	match s:
		State.IDLE, State.NOTICE:
			_switch_anim("idle")
		State.WANDER, State.RETURN:
			_switch_anim("walk")
		State.CHASE, State.FLEE:
			_switch_anim("run")

func _start_idle() -> void:
	_set_state(State.IDLE)
	_timer = randf_range(youn_data.idle_time_min, youn_data.idle_time_max)

func _start_wander() -> void:
	_set_state(State.WANDER)
	var angle := randf() * TAU
	var radius := randf_range(2.0, youn_data.wander_radius)
	_target = _origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	_timer = 4.0

func _start_notice() -> void:
	_set_state(State.NOTICE)
	_notice_delay = randf_range(youn_data.notice_delay_min, youn_data.notice_delay_max)

func _start_return() -> void:
	_set_state(State.RETURN)
	_target = _origin

func _start_flee(from_position: Vector3) -> void:
	_engaging_combat = true
	touch_area.monitoring = false
	collision.disabled = true
	_set_state(State.FLEE)
	_timer = FLEE_TIME
	_flee_dir = (global_position - from_position) * Vector3(1, 0, 1)
	if _flee_dir.length() < 0.01:
		_flee_dir = Vector3(0, 0, -1)
	else:
		_flee_dir = _flee_dir.normalized()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _can_see_player(range_override := -1.0) -> bool:
	if _player == null:
		return false
	var dist := youn_data.detect_range if range_override < 0.0 else range_override
	return _player.global_position.distance_to(global_position) <= dist

func _is_outside_leash(buffer := 1.0) -> bool:
	return global_position.distance_to(_origin) > youn_data.leash_range * buffer

func _face_dir(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), youn_data.rotate_speed * delta)

func _snap_to_ground() -> void:
	var start := global_position + Vector3.UP * 8.0
	var finish := global_position + Vector3.DOWN * 24.0
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = hit.position.y + youn_data.collision_height * 0.5

# ── Combat trigger ────────────────────────────────────────────────────────────

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
		var to_enemy := (global_position - _player.global_position) * Vector3(1, 0, 1)
		if to_enemy.length() > 0.01:
			_player.rotation.y = atan2(to_enemy.x, to_enemy.z)
		var to_player := ((_player.global_position - global_position) * Vector3(1, 0, 1))
		if to_player.length() > 0.01:
			rotation.y = atan2(to_player.x, to_player.z)
	set_physics_process(false)
	popup_label.text = youn_data.youn_name + "\n" + LocalizationState.t("world.enemy.press_enter")
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
	GameState.pending_wild_youn_data = youn_data
	if GameState.player_save != null and GameState.player_save.needs_bathroom:
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
	drop.item_name = youn_data.loot_item_name
	drop.gold_amount = youn_data.loot_gold
	get_parent().add_child(drop)
