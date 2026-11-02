class_name DialogueLayout
extends RefCounted

## Geometría visual de la caja de diálogo: anchors de la caja/portrait/
## nameplate y la posición del portrait cuando el diálogo está espejado.
## Separado de DialogueBox para que el tipeo de texto y el layout no
## compartan un solo archivo; recibe los Control directo, igual que
## DialogueChoiceMenu/DialogueToast reciben su host.

const PORTRAIT_CANVAS_SIZE := Vector2(2400.0, 2400.0)
const PORTRAIT_FRAME_LEFT_INSET := -36.0
const PORTRAIT_FRAME_TOP_RATIO := 0.3
const NAMEPLATE_WIDTH := 360.0
const NAMEPLATE_INSET := 32.0

var _root: Control
var _dialogue_box: Control
var _portrait: TextureRect
var _portrait_frame: Control
var _speaker_plate: ColorRect
var _text_margin: MarginContainer

func _init(root: Control, dialogue_box: Control, portrait: TextureRect,
		portrait_frame: Control, speaker_plate: ColorRect, text_margin: MarginContainer) -> void:
	_root = root
	_dialogue_box = dialogue_box
	_portrait = portrait
	_portrait_frame = portrait_frame
	_speaker_plate = speaker_plate
	_text_margin = text_margin

func reset() -> void:
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_box.anchor_top = 0.65
	_dialogue_box.anchor_bottom = 0.95
	_dialogue_box.offset_top = 0.0
	_dialogue_box.offset_bottom = 0.0
	_portrait_frame.anchor_top = PORTRAIT_FRAME_TOP_RATIO
	_portrait_frame.anchor_bottom = 1.0
	_portrait_frame.offset_top = 0.0
	_portrait_frame.offset_bottom = 0.0
	_speaker_plate.anchor_top = 0.0
	_speaker_plate.anchor_bottom = 0.0
	_speaker_plate.offset_top = -26.0
	_speaker_plate.offset_bottom = 28.0

func set_nameplate_side(side: String) -> void:
	if side == "right":
		_speaker_plate.anchor_left = 1.0
		_speaker_plate.anchor_right = 1.0
		_speaker_plate.offset_left = -NAMEPLATE_WIDTH - NAMEPLATE_INSET
		_speaker_plate.offset_right = -NAMEPLATE_INSET
		return
	_speaker_plate.anchor_left = 0.0
	_speaker_plate.anchor_right = 0.0
	_speaker_plate.offset_left = NAMEPLATE_INSET
	_speaker_plate.offset_right = NAMEPLATE_WIDTH + NAMEPLATE_INSET

func apply_mirrored(mirrored: bool) -> void:
	_dialogue_box.anchor_left = 0.08 if mirrored else 0.22
	_dialogue_box.anchor_right = 0.78 if mirrored else 0.92
	if mirrored:
		_portrait_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_portrait_frame.anchor_left = 0.0
		_portrait_frame.anchor_right = 0.37
		_portrait_frame.offset_left = PORTRAIT_FRAME_LEFT_INSET
		_portrait_frame.offset_right = 36.0
	if mirrored:
		_text_margin.offset_right = -300.0
		return
	_text_margin.offset_right = -54.0

## Posiciona y configura el portrait para la línea actual. `position`/`scale`
## llegan en coordenadas "normales" (no espejadas); si `mirrored`, calcula la
## posición reflejada a partir del tamaño del canvas del portrait.
func apply_portrait(texture: Texture2D, mirrored: bool, position: Vector2, scale: Vector2) -> void:
	var final_position := position
	if mirrored:
		var normal_left := PORTRAIT_FRAME_LEFT_INSET + position.x
		var portrait_width := PORTRAIT_CANVAS_SIZE.x * scale.x
		final_position.x = _root.size.x - normal_left - portrait_width
		final_position.y = _root.size.y * PORTRAIT_FRAME_TOP_RATIO + position.y
	_portrait.texture = texture
	_portrait.visible = texture != null
	_portrait.flip_h = mirrored
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.size = PORTRAIT_CANVAS_SIZE
	_portrait.position = final_position
	_portrait.scale = scale
