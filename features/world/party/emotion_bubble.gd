extends AnimatedSprite3D

const DISPLAY_SECONDS  := 3.0
const FLOAT_AMPLITUDE  := 0.05
const FLOAT_PERIOD     := 1.6
const CYCLE_PAUSE      := 10.0

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
	_update_height()

	if debug_emotion != "":
		call_deferred("show_emotion", debug_emotion)
	elif debug_random:
		call_deferred("_show_random_emotion")
	else:
		call_deferred("_start_cycle")


func setup(bubble_frames: SpriteFrames, icon_frames: SpriteFrames) -> void:
	sprite_frames       = bubble_frames
	_icon.sprite_frames = icon_frames


func _update_height() -> void:
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
	if _state == State.HIDDEN or _state == State.PAUSING:
		_state = State.HIDDEN
		_start_cycle()


func show_emotion(state_name: String) -> void:
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
	if StatsManager.emotions_blocked:
		_state = State.HIDDEN
		return
	_queue.clear()
	for emotion_name in StatsManager.active_states:
		if _icon.sprite_frames != null and _icon.sprite_frames.has_animation(emotion_name):
			_queue.append(emotion_name)
	if not _queue.is_empty():
		show_emotion(_queue.pop_front())


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
