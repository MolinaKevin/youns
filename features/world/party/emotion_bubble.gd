extends AnimatedSprite3D

const DISPLAY_SECONDS  := 3.0
const FLOAT_AMPLITUDE  := 0.05
const FLOAT_PERIOD     := 1.6
const CYCLE_PAUSE      := 5.0

const BUBBLE_FRAMES_PATH := "res://assets/emotions/bubble_frames.tres"
const ICON_FRAMES_PATH   := "res://assets/emotions/emotion_frames.tres"

@export var debug_emotion      : String = ""
@export var debug_random       : bool   = false


@export var pixel_size_override: float  = 0.008
@export var height_margin      : float  = 0.3

enum State { HIDDEN, SHOWING, POPPING, PAUSING }
var _state         := State.HIDDEN
var _display_timer := 0.0
var _pause_timer   := 0.0
var _float_time    := 0.0
var _base_y        := 0.0
var _icon          : AnimatedSprite3D
var _queue         : Array[String] = []
var _frozen        := false


func _ready() -> void:
	_icon = AnimatedSprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = pixel_size_override
	_icon.render_priority = 1
	_icon.name = "EmotionIcon"
	add_child(_icon)

	billboard       = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size      = pixel_size_override
	render_priority = 0
	visible         = false
	animation_finished.connect(_on_animation_finished)
	StatsManager.stat_changed.connect(_on_stat_changed)
	update_height()
	_load_frames()

	if debug_emotion != "":
		call_deferred("show_emotion", debug_emotion)
	elif debug_random:
		call_deferred("_show_random_emotion")
	else:
		call_deferred("_start_cycle")


## Carga los SpriteFrames de la burbuja y de los íconos de emoción desde
## disco, u los genera y los hornea la primera vez (o si les falta una
## animación agregada después, como "evolving").
func _load_frames() -> void:
	var bubble_frames: SpriteFrames
	if ResourceLoader.exists(BUBBLE_FRAMES_PATH):
		bubble_frames = load(BUBBLE_FRAMES_PATH)
	else:
		bubble_frames = _build_bubble_frames()
		ResourceSaver.save(bubble_frames, BUBBLE_FRAMES_PATH)

	var icon_frames: SpriteFrames
	if ResourceLoader.exists(ICON_FRAMES_PATH):
		icon_frames = load(ICON_FRAMES_PATH)
		if not icon_frames.has_animation("evolving"):
			_patch_emotion_frames(icon_frames)
			ResourceSaver.save(icon_frames, ICON_FRAMES_PATH)
	else:
		icon_frames = _build_emotion_frames()
		ResourceSaver.save(icon_frames, ICON_FRAMES_PATH)

	sprite_frames       = bubble_frames
	_icon.sprite_frames = icon_frames


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


func _patch_emotion_frames(sf: SpriteFrames) -> void:
	const CELL_W   := 40
	const CELL_H   := 58
	const OFFSET_X := 15
	var tex: Texture2D = load("res://assets/emotions/mixed.png")
	sf.add_animation("evolving")
	sf.set_animation_speed("evolving", 4.0)
	sf.set_animation_loop("evolving", true)
	for cell in [[4, 0], [5, 0], [6, 0]]:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(OFFSET_X + cell[0] * CELL_W, cell[1] * CELL_H, CELL_W, CELL_H)
		sf.add_frame("evolving", atlas)


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
		["evolving", 4.0, true, [[4,0],[5,0],[6,0]]],  # placeholder: mismas frames que tired
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


func update_height() -> void:
	var data: YounData = get_parent().get("youn_data")
	var h := 1.0
	if data:
		h = data.body_height * data.mesh_scale + data.mesh_y_offset
	_base_y    = h + height_margin
	position.y = _base_y


func _process(delta: float) -> void:
	match _state:
		State.SHOWING:
			_display_timer -= delta
			if _display_timer <= 0.0:
				_play_pop()
			else:
				_float_time += delta
				position.y = _base_y + sin(_float_time * TAU / FLOAT_PERIOD) * FLOAT_AMPLITUDE
		State.PAUSING:
			_pause_timer -= delta
			if _pause_timer <= 0.0:
				_state = State.HIDDEN
				_start_cycle()

	if OS.is_debug_build() and Input.is_action_just_pressed("ui_focus_next"):
		_debug_cycle_emotion()


func _on_stat_changed() -> void:
	var new_queue := EmotionDisplayQueue.build(
		StatsManager.active_states, StatsManager.emotions_blocked, _icon.sprite_frames)
	if new_queue.is_empty():
		return
	if _state == State.HIDDEN or _state == State.PAUSING:
		_state = State.HIDDEN
		_start_cycle()
	elif _state == State.SHOWING and "evolving" in new_queue and _icon.animation != "evolving":
		_queue = new_queue
		_queue.erase("evolving")
		show_emotion("evolving")


func freeze() -> void:
	_frozen = true
	visible = false


func unfreeze() -> void:
	_frozen = false


func show_emotion(state_name: String) -> void:
	if _frozen:
		return
	if _icon.sprite_frames == null or not _icon.sprite_frames.has_animation(state_name):
		push_warning("EmotionBubble: emoción '%s' no encontrada" % state_name)
		return
	_icon.play(state_name)
	_icon.visible   = true
	if sprite_frames and sprite_frames.has_animation("idle"):
		play("idle")
	visible        = true
	_float_time    = 0.0
	_state         = State.SHOWING
	_display_timer = DISPLAY_SECONDS


func _play_pop() -> void:
	_icon.visible = false
	if sprite_frames and sprite_frames.has_animation("pop"):
		play("pop")
		_state = State.POPPING
	else:
		_on_pop_finished()


func _on_animation_finished() -> void:
	if _state == State.POPPING:
		_on_pop_finished()


func _on_pop_finished() -> void:
	visible    = false
	position.y = _base_y
	if not _queue.is_empty():
		show_emotion(_queue.pop_front())
	else:
		_state = State.PAUSING
		_pause_timer = CYCLE_PAUSE


func _start_cycle() -> void:
	_queue = EmotionDisplayQueue.build(
		StatsManager.active_states, StatsManager.emotions_blocked, _icon.sprite_frames)
	if not _queue.is_empty():
		show_emotion(_queue.pop_front())
	else:
		_state = State.PAUSING
		_pause_timer = CYCLE_PAUSE


func get_active_emotions() -> Array[String]:
	var result: Array[String] = []
	if _state == State.SHOWING and not _icon.animation.is_empty():
		result.append(_icon.animation)
	result.append_array(_queue)
	return result


func _show_random_emotion() -> void:
	show_emotion("sleep")


var _debug_index := 0
func _debug_cycle_emotion() -> void:
	if _icon.sprite_frames == null:
		return
	var anims := _icon.sprite_frames.get_animation_names()
	if anims.is_empty():
		return
	_debug_index = (_debug_index + 1) % anims.size()
	show_emotion(anims[_debug_index])
