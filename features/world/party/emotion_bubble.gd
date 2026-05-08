extends AnimatedSprite3D  # este nodo es la BURBUJA (idle + pop)

const CHECK_INTERVAL  := 5.0
const DISPLAY_SECONDS := 3.0
const FLOAT_AMPLITUDE := 0.05   # metros
const FLOAT_PERIOD    := 1.6    # segundos por ciclo
const STATE_PRIORITY  := ["sick", "bathroom", "sleep", "tired", "hungry", "sad", "stressed", "bored"]

@export var debug_emotion      : String = ""
@export var debug_random       : bool   = false
@export var pixel_size_override: float  = 0.008
@export var height_margin      : float  = 0.3

enum State { HIDDEN, SHOWING, POPPING }
var _state         := State.HIDDEN
var _display_timer := 0.0
var _check_timer   := 0.0
var _float_time    := 0.0
var _base_y        := 0.0
var _icon          : AnimatedSprite3D


func _ready() -> void:
	_icon = AnimatedSprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.pixel_size = pixel_size_override
	_icon.render_priority = 1
	_icon.name = "EmotionIcon"
	add_child(_icon)

	billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size  = pixel_size_override
	render_priority = 0
	visible     = false
	_check_timer = CHECK_INTERVAL
	animation_finished.connect(_on_animation_finished)
	_update_height()

	if debug_emotion != "":
		call_deferred("show_emotion", debug_emotion)
	elif debug_random:
		call_deferred("_show_random_emotion")


# Llamado desde youn_3d con los dos SpriteFrames separados
func setup(bubble_frames: SpriteFrames, icon_frames: SpriteFrames) -> void:
	sprite_frames      = bubble_frames
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
		State.HIDDEN:
			_check_timer -= delta
			if _check_timer <= 0.0:
				_check_timer = CHECK_INTERVAL
				_try_show_current_state()

	if OS.is_debug_build() and Input.is_action_just_pressed("ui_focus_next"):
		_debug_cycle_emotion()


func show_emotion(state_name: String) -> void:
	if _icon.sprite_frames == null or not _icon.sprite_frames.has_animation(state_name):
		push_warning("EmotionBubble: emoción '%s' no encontrada" % state_name)
		return
	_icon.play(state_name)
	_icon.visible = true
	if sprite_frames and sprite_frames.has_animation("idle"):
		play("idle")
	visible      = true
	_float_time  = 0.0
	_state       = State.SHOWING
	_display_timer = DISPLAY_SECONDS


func _play_pop() -> void:
	_icon.visible = false
	if sprite_frames and sprite_frames.has_animation("pop"):
		play("pop")
		_state = State.POPPING
	else:
		_hide_bubble()


func _on_animation_finished() -> void:
	if _state == State.POPPING:
		_hide_bubble()


func _hide_bubble() -> void:
	visible    = false
	position.y = _base_y
	_state     = State.HIDDEN
	_check_timer = CHECK_INTERVAL


func _try_show_current_state() -> void:
	if _state != State.HIDDEN:
		return
	if debug_random:
		_show_random_emotion()
		return
	var ps := GameState.player_save
	if ps == null:
		return
	for state in STATE_PRIORITY:
		if _state_is_active(state, ps):
			show_emotion(state)
			return


func _show_random_emotion() -> void:
	show_emotion("sleep")


func _state_is_active(state: String, ps: PlayerSaveData) -> bool:
	match state:
		"sick":     return ps.enfermo
		"bathroom": return ps.needs_bathroom
		"tired":    return ps.cansancio < 20
		"sleep":    return _in_sleep_range()
		"sad":      return ps.felicidad < 30
		"hungry":   return ps.hambre > 70
		"stressed": return ps.estres > 70
		"bored":    return ps.aburrimiento > 70
	return false


func _in_sleep_range() -> bool:
	var parent := get_parent()
	if not is_instance_valid(parent):
		return false
	var data: YounData = parent.get("youn_data")
	if data == null:
		return false
	var hour := GameState.time_of_day_hours
	if data.sleep_hour > data.wake_hour:
		return hour >= float(data.sleep_hour) or hour < float(data.wake_hour)
	return hour >= float(data.sleep_hour) and hour < float(data.wake_hour)


var _debug_index := 0
func _debug_cycle_emotion() -> void:
	if _icon.sprite_frames == null:
		return
	var anims := _icon.sprite_frames.get_animation_names()
	if anims.is_empty():
		return
	_debug_index = (_debug_index + 1) % anims.size()
	show_emotion(anims[_debug_index])
