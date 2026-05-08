extends CharacterBody3D

const GRAVITY     := 20.0
const FOLLOW_DIST := 2.0
const STOP_DIST   := 1.2

@export var youn_data: YounData

var _player: CharacterBody3D
var _bodies: Dictionary = {}   # "idle" -> Node3D, "walk" -> Node3D, etc.
var _current_anim: String = ""
var _emotion_bubble: AnimatedSprite3D = null


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_setup_emotion_bubble()
	if youn_data:
		_load_model(youn_data)


func load_youn(data: YounData) -> void:
	youn_data = data
	for body in _bodies.values():
		body.queue_free()
	_bodies.clear()
	_current_anim = ""
	_load_model(data)
	if _emotion_bubble:
		_emotion_bubble._update_height()


func _load_model(data: YounData) -> void:
	var mat: StandardMaterial3D = null
	if data.texture:
		mat = StandardMaterial3D.new()
		mat.albedo_texture = data.texture
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var scene_map: Dictionary = {
		"idle":    data.scene_idle,
		"walk":    data.scene_walk,
		"run":     data.scene_run,
		"attack":  data.scene_attack,
		"range":   data.scene_range,
		"damage":  data.scene_damage,
		"die":     data.scene_die,
		"evolve":  data.scene_evolve,
	}

	for key in scene_map:
		var packed: PackedScene = scene_map[key]
		if not packed:
			continue
		var body: Node3D = packed.instantiate()
		body.scale = Vector3.ONE * data.mesh_scale
		body.position.y = data.mesh_y_offset
		body.visible = false
		add_child(body)
		if mat:
			for mesh in _find_meshes(body):
				mesh.material_override = mat
		_bodies[key] = body

	print("EmotionBubble loaded bodies: ", _bodies.keys())
	_switch_to("idle")


func _switch_to(anim_key: String) -> void:
	# Si la animación pedida no existe, cae al idle
	var target := anim_key if anim_key in _bodies else "idle"
	if _current_anim == target:
		return
	if _current_anim in _bodies:
		_bodies[_current_anim].visible = false
	_current_anim = target
	if target in _bodies:
		var body: Node3D = _bodies[target]
		body.visible = true
		var anim_player := _find_anim_player(body)
		if anim_player:
			var list := anim_player.get_animation_list()
			if not list.is_empty():
				var anim_name := list[0]
				var anim := anim_player.get_animation(anim_name)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR
				anim_player.play(anim_name)


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
		var dir := to_player.normalized()
		velocity.x = dir.x * (youn_data.chase_speed if youn_data else 5.8)
		velocity.z = dir.z * (youn_data.chase_speed if youn_data else 5.8)
		_face_dir(dir, delta)
		_switch_to("run")
	elif dist > STOP_DIST:
		var dir := to_player.normalized()
		var speed := (youn_data.wander_speed if youn_data else 2.2) * (dist / FOLLOW_DIST)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face_dir(dir, delta)
		_switch_to("walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_switch_to("idle")

	move_and_slide()


func play_anim(anim_key: String) -> void:
	_switch_to(anim_key)

func get_current_anim() -> String:
	return _current_anim


func show_emotion(state_name: String) -> void:
	if _emotion_bubble:
		_emotion_bubble.show_emotion(state_name)


func get_active_emotions() -> Array[String]:
	if _emotion_bubble:
		return _emotion_bubble.get_active_emotions()
	return []


func _face_dir(dir: Vector3, delta: float) -> void:
	var rotate_speed := youn_data.rotate_speed if youn_data else 8.0
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, rotate_speed * delta)


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


# ── Emotion bubble ────────────────────────────────────────────────────────────

func _setup_emotion_bubble() -> void:
	var bubble := get_node_or_null("EmotionBubble") as AnimatedSprite3D
	if bubble == null:
		bubble = AnimatedSprite3D.new()
		bubble.set_script(preload("res://features/world/party/emotion_bubble.gd"))
		bubble.name = "EmotionBubble"
		add_child(bubble)

	var bubble_path := "res://assets/emotions/bubble_frames.tres"
	var bubble_frames: SpriteFrames
	if ResourceLoader.exists(bubble_path):
		bubble_frames = load(bubble_path)
	else:
		bubble_frames = _build_bubble_frames()
		ResourceSaver.save(bubble_frames, bubble_path)

	var icon_path := "res://assets/emotions/emotion_frames.tres"
	var icon_frames: SpriteFrames
	if ResourceLoader.exists(icon_path):
		icon_frames = load(icon_path)
	else:
		icon_frames = _build_emotion_frames()
		ResourceSaver.save(icon_frames, icon_path)

	bubble.call("setup", bubble_frames, icon_frames)
	_emotion_bubble = bubble


# SpriteFrames de la burbuja: "idle" (flota) y "pop" (explosión)
func _build_bubble_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()

	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", load("res://assets/emotions/bubble.png"))

	# pop: frames placeholder — ajustar en el editor con bubble_frames.tres
	sf.add_animation("pop")
	sf.set_animation_speed("pop", 10.0)
	sf.set_animation_loop("pop", false)
	var tex: Texture2D = load("res://assets/emotions/mixed.png")
	for region in [Rect2(296, 58, 80, 58), Rect2(385, 58, 62, 58), Rect2(383, 0, 66, 58)]:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		sf.add_frame("pop", atlas)

	return sf


# SpriteFrames de los íconos de emoción
func _build_emotion_frames() -> SpriteFrames:
	const CELL_W   := 40
	const CELL_H   := 58
	const OFFSET_X := 15

	# Fila 0 (y=0):   [0]=burbuja vacía · [1-3]=manzana · [4-6]=swirl · [7-8]=calavera
	# Fila 1 (y=58):  [0-1]=stress/cura · [2-3]=mariposa · [4-6]=sparkle
	# Fila 2 (y=116): [0-2]=ciervo · [3-4]=gotas · [5-7]=ZZZ

	# [nombre, fps, loop, [[col, fila], ...]]
	var defs: Array = [
		["hungry",   5.0, true, [[1,0],[2,0],[3,0]]],
		["tired",    4.0, true, [[4,0],[5,0],[6,0]]],
		["sick",     4.0, true, [[7,0],[8,0]]],
		["stressed", 3.0, true, [[0,1]]],
		["bored",    6.0, true, [[2,1],[3,1]]],
		["sad",      4.0, true, [[3,2],[4,2]]],
		["sleep",    3.0, true, [[5,2],[6,2],[7,2]]],
	]

	var tex: Texture2D = load("res://assets/emotions/mixed.png")
	var sf := SpriteFrames.new()
	for entry in defs:
		var anim_name: String = entry[0]
		var fps: float        = entry[1]
		var loop: bool        = entry[2]
		var cells: Array      = entry[3]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		for cell in cells:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(OFFSET_X + cell[0] * CELL_W, cell[1] * CELL_H, CELL_W, CELL_H)
			sf.add_frame(anim_name, atlas)
	return sf
