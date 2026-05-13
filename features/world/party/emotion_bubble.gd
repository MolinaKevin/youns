extends AnimatedSprite3D

const DISPLAY_SECONDS  := 3.0
const FLOAT_AMPLITUDE  := 0.05
const FLOAT_PERIOD     := 1.6
const RULES_DIR        := "res://data/emotions/rules/"

@export var debug_emotion      : String = ""
@export var debug_random       : bool   = false
@export var pixel_size_override: float  = 0.008
@export var height_margin      : float  = 0.3

enum State { HIDDEN, SHOWING, POPPING }
var _state         := State.HIDDEN
var _display_timer := 0.0
var _float_time    := 0.0
var _base_y        := 0.0
var _icon          : AnimatedSprite3D
var _queue         : Array[String] = []
var _rules         : Array[EmotionRule] = []


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

	_rules = _load_rules()

	if debug_emotion != "":
		call_deferred("show_emotion", debug_emotion)
	elif debug_random:
		call_deferred("_show_random_emotion")


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


	if OS.is_debug_build() and Input.is_action_just_pressed("ui_focus_next"):
		_debug_cycle_emotion()


func _on_stat_changed() -> void:
	_evaluate_and_show()

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
		_hide_bubble()


func _on_animation_finished() -> void:
	if _state == State.POPPING:
		_hide_bubble()


func get_active_emotions() -> Array[String]:
	var result: Array[String] = []
	if _state == State.SHOWING and not _icon.animation.is_empty():
		result.append(_icon.animation)
	result.append_array(_queue)
	return result


func _hide_bubble() -> void:
	visible    = false
	position.y = _base_y
	_state     = State.HIDDEN
	if not _queue.is_empty():
		show_emotion(_queue.pop_front())


func _evaluate_and_show() -> void:
	if _state != State.HIDDEN or StatsManager.emotions_blocked:
		return
	if debug_random:
		_show_random_emotion()
		return
	var ps := GameState.player_save
	if ps == null or _rules.is_empty():
		return
	var ctx := {
		"save": ps,
		"youn_data": get_parent().get("youn_data"),
	}
	_queue = EmotionEngine.evaluate(_rules, ctx)
	if not _queue.is_empty():
		show_emotion(_queue.pop_front())


func _load_rules() -> Array[EmotionRule]:
	var result: Array[EmotionRule] = []
	var dir := DirAccess.open(RULES_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var rule = load(RULES_DIR + file)
			if rule is EmotionRule:
				result.append(rule)
		file = dir.get_next()
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
