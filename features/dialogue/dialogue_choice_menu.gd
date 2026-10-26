class_name DialogueChoiceMenu
extends RefCounted

## Menú vertical navegable para elegir una opción (Dialogue.ask()), reusando
## el panel/borde de la caja de diálogo. `host` es el autoload Dialogue, dueño
## exclusivo de esta instancia. Sin tipo propio porque los autoloads de este
## proyecto no declaran class_name.

const COLOR_NORMAL := Color(0.96, 0.93, 0.84, 1)
const COLOR_SELECTED := Color(0.96, 0.86, 0.62, 1)

var host

var options: Array[String] = []
var buttons: Array[Button] = []
var index := 0
var active := false

func _init(p_host) -> void:
	host = p_host

## Muestra `p_options` como menú vertical navegable y devuelve el índice
## elegido (-1 si se cancela). Reusa el mismo panel/borde que la caja de
## diálogo. El host conserva el estado de pausa y sus nodos privados.
func ask(p_options: Array[String]) -> int:
	if p_options.is_empty() or active:
		return -1
	options = p_options.duplicate()
	active = true
	host.open_choice_menu()
	_build_buttons()
	highlight(0)
	return await host.choice_made

func _build_buttons() -> void:
	_clear_buttons()
	for i in options.size():
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 24)
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.mouse_entered.connect(highlight.bind(i))
		btn.pressed.connect(resolve.bind(i))
		host.add_choice_button(btn)
		buttons.append(btn)

func _clear_buttons() -> void:
	for btn in buttons:
		btn.queue_free()
	buttons.clear()

func highlight(i: int) -> void:
	index = i
	for j in buttons.size():
		var selected := j == index
		var btn := buttons[j]
		btn.text = ("▶  " if selected else "    ") + options[j]
		btn.add_theme_color_override("font_color", COLOR_SELECTED if selected else COLOR_NORMAL)

func resolve(i: int) -> void:
	if not active:
		return
	active = false
	host.close_choice_menu()
	_clear_buttons()
	host.resolve_choice(i)

## true si consumió el evento.
func handle_input(event: InputEvent) -> bool:
	if buttons.is_empty():
		return false
	if event.is_action_pressed("move_up", true) or event.is_action_pressed("ui_up", true):
		highlight((index - 1 + buttons.size()) % buttons.size())
		return true
	if event.is_action_pressed("move_down", true) or event.is_action_pressed("ui_down", true):
		highlight((index + 1) % buttons.size())
		return true
	if event.is_action_pressed("ui_accept"):
		resolve(index)
		return true
	if event.is_action_pressed("ui_cancel"):
		resolve(-1)
		return true
	return false
