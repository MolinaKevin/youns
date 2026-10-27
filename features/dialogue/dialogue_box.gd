extends CanvasLayer

const DebugLogging := preload("res://shared/debug_logging.gd")

## Servicio global de diálogo. Cada entrada usa las claves `speaker`, `text`
## y, opcionalmente, `portrait` (Texture2D).
signal line_changed(index: int)
signal dialogue_finished
signal choice_made(index: int)

const CHARACTERS_PER_SECOND := 55.0
const NAMEPLATE_WIDTH := 360.0
const NAMEPLATE_INSET := 32.0
const PORTRAIT_CANVAS_SIZE := Vector2(2400.0, 2400.0)
const PORTRAIT_FRAME_LEFT_INSET := -36.0
const PORTRAIT_FRAME_TOP_RATIO := 0.3
const DEBUG_LAYOUT := false

@onready var _root: Control = $Root
@onready var _dialogue_box: Control = $Root/DialogueBox
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _speaker_plate: ColorRect = %SpeakerPlate
@onready var _text_label: Label = %DialogueText
@onready var _portrait: TextureRect = %Portrait
@onready var _portrait_frame: Control = %PortraitFrame
@onready var _text_margin: MarginContainer = %TextMargin
@onready var _continue_hint: Label = %ContinueHint
@onready var _choice_menu: Control = %ChoiceMenu
@onready var _choice_list: VBoxContainer = %List
@onready var _toast: Control = %Toast
@onready var _toast_label: Label = %ToastLabel

var _lines: Array[Dictionary] = []
var _line_index := -1
var _visible_characters := 0.0
var _typing := false
var _dialogue_modal: ModalScreenContext
## La elección puede abrirse dentro de un diálogo ya pausado o sola. Conserva
## su propia pausa para no sobrescribir la que pertenece al diálogo.
var _choice_modal: ModalScreenContext

var _choice_menu_logic: DialogueChoiceMenu
var _toast_notifier: DialogueToast


func _ready() -> void:
	_root.hide()
	_dialogue_modal = ModalScreenContext.new(ModalScreenHost.new(GlobalHUD, GameState, ZoneManager, PartyManager))
	_choice_modal = ModalScreenContext.new(ModalScreenHost.new(GlobalHUD, GameState, ZoneManager, PartyManager))
	_choice_menu_logic = DialogueChoiceMenu.new(self)
	_toast_notifier = DialogueToast.new(self)


func start(lines: Array[Dictionary], mirrored := false) -> void:
	if lines.is_empty():
		finish()
		return

	_lines = []
	for line: Dictionary in lines:
		var configured_line := line.duplicate()
		configured_line["mirrored"] = bool(configured_line.get("mirrored", mirrored))
		_lines.append(configured_line)
	_line_index = 0
	_dialogue_modal.enter_overlay(self)
	_root.show()
	_show_current_line()


func say(speaker: String, text: String, portrait: Texture2D = null) -> void:
	start([{"speaker": speaker, "text": text, "portrait": portrait}])


func finish() -> void:
	var was_playing := is_playing()
	_lines.clear()
	_line_index = -1
	_typing = false
	_root.hide()
	_dialogue_modal.exit_overlay(self)
	if was_playing:
		dialogue_finished.emit()


func is_playing() -> bool:
	return _line_index >= 0 and _line_index < _lines.size()


## True mientras haya una línea o un menú de opciones en pantalla.
func is_busy() -> bool:
	return is_playing() or _choice_menu_logic.active


## Notificación flotante no-modal (no pausa el juego) con el mismo panel/borde
## que la caja de diálogo. Se desvanece sola después de `duration` segundos.
func toast(text: String, duration: float = 2.5) -> void:
	_toast_notifier.show_text(text, duration)


## Muestra `options` como menú vertical navegable y devuelve el índice elegido
## (-1 si se cancela). Reusa el mismo panel/borde que la caja de diálogo.
func ask(options: Array[String]) -> int:
	return await _choice_menu_logic.ask(options)


## Abre el menú de elección y toma la pausa temporal que le corresponde. La
## lógica de botones no manipula nodos ni estado de pausa privados.
func open_choice_menu() -> void:
	_choice_modal.enter_overlay(self)
	_root.show()
	_choice_menu.show()


## Cierra el menú de elección y restaura sólo la pausa que abrió él mismo.
func close_choice_menu() -> void:
	_choice_menu.hide()
	_choice_modal.exit_overlay(self)
	if not is_playing():
		_root.hide()


func add_choice_button(button: Button) -> void:
	_choice_list.add_child(button)


func resolve_choice(index: int) -> void:
	choice_made.emit(index)


func show_toast_panel(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast.show()


func set_toast_alpha(alpha: float) -> void:
	_toast_label.modulate.a = alpha


func hide_toast_panel() -> void:
	_toast.hide()


func _process(delta: float) -> void:
	if not _typing:
		_continue_hint.modulate.a = 0.72 + 0.28 * (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
		return

	_continue_hint.modulate.a = 0.82
	_visible_characters = minf(_visible_characters + CHARACTERS_PER_SECOND * delta, _text_label.text.length())
	_text_label.visible_characters = floori(_visible_characters)
	if _text_label.visible_characters >= _text_label.text.length():
		_typing = false
		_continue_hint.text = LocalizationState.t("dialogue.continue")
		_continue_hint.show()


func _input(event: InputEvent) -> void:
	if _choice_menu_logic.active:
		if _choice_menu_logic.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if handle_input(event):
		get_viewport().set_input_as_handled()


func handle_input(event: InputEvent) -> bool:
	if not is_playing():
		return false
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		return true
	return false


func advance() -> void:
	if _typing:
		_visible_characters = _text_label.text.length()
		_text_label.visible_characters = -1
		_typing = false
		_continue_hint.text = LocalizationState.t("dialogue.continue")
		_continue_hint.show()
		return

	if _line_index + 1 >= _lines.size():
		finish()
		return
	_line_index += 1
	_show_current_line()


func _show_current_line() -> void:
	var line := _lines[_line_index]
	var mirrored := bool(line.get("mirrored", false))
	_reset_layout()
	_speaker_label.text = str(line.get("speaker", ""))
	_speaker_label.visible = not _speaker_label.text.is_empty()
	_set_mirrored_layout(mirrored)
	_set_nameplate_side(_mirrored_side(str(line.get("nameplate_side", "left"))) if mirrored else str(line.get("nameplate_side", "left")))
	_text_label.text = str(line.get("text", ""))

	var portrait_texture := line.get("portrait") as Texture2D
	var portrait_position: Vector2 = line.get("portrait_position", Vector2(-145, -70))
	var portrait_scale: Vector2 = line.get("portrait_scale", Vector2(0.36, 0.36))
	if mirrored:
		var normal_left := PORTRAIT_FRAME_LEFT_INSET + portrait_position.x
		var portrait_width := PORTRAIT_CANVAS_SIZE.x * portrait_scale.x
		portrait_position.x = _root.size.x - normal_left - portrait_width
		portrait_position.y = _root.size.y * PORTRAIT_FRAME_TOP_RATIO + portrait_position.y
	_portrait.texture = portrait_texture
	_portrait.visible = portrait_texture != null
	_portrait.flip_h = mirrored
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.size = PORTRAIT_CANVAS_SIZE
	_portrait.position = portrait_position
	_portrait.scale = portrait_scale
	if DEBUG_LAYOUT and _line_index == 0:
		if DebugLogging.verbose_enabled():
			call_deferred("_log_layout", _speaker_label.text, mirrored, portrait_position)

	_visible_characters = 0.0
	_text_label.visible_characters = 0
	_typing = not _text_label.text.is_empty()
	_continue_hint.text = LocalizationState.t("dialogue.accept_to_speed_up") if _typing else LocalizationState.t("dialogue.continue")
	_continue_hint.show()
	if not _typing:
		_continue_hint.modulate.a = 1.0
	line_changed.emit(_line_index)


func _set_nameplate_side(side: String) -> void:
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


func _set_mirrored_layout(mirrored: bool) -> void:
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


func _reset_layout() -> void:
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


func _log_layout(speaker: String, mirrored: bool, portrait_position: Vector2) -> void:
	if not DebugLogging.verbose_enabled():
		return
	var viewport_rect := get_viewport().get_visible_rect()
	print("[DialogueLayout] speaker=%s mirrored=%s viewport=%s root=(pos=%s size=%s) box=(rect=%s anchors=(%s,%s,%s,%s)) frame=(rect=%s anchors=(%s,%s,%s,%s)) portrait=(pos=%s scale=%s rect=%s)" % [
		speaker,
		mirrored,
		viewport_rect,
		_root.position,
		_root.size,
		_dialogue_box.get_global_rect(),
		_dialogue_box.anchor_left,
		_dialogue_box.anchor_top,
		_dialogue_box.anchor_right,
		_dialogue_box.anchor_bottom,
		_portrait_frame.get_global_rect(),
		_portrait_frame.anchor_left,
		_portrait_frame.anchor_top,
		_portrait_frame.anchor_right,
		_portrait_frame.anchor_bottom,
		portrait_position,
		_portrait.scale,
		_portrait.get_global_rect(),
	])


func _mirrored_side(side: String) -> String:
	return "left" if side == "right" else "right"
