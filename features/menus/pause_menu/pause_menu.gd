extends CanvasLayer

var enabled := false
var _clock_was_visible := true
var _status_was_visible := false

@onready var continue_button = $Panel/VBox/ContinueButton
@onready var deck_button = $Panel/VBox/DeckButton
@onready var quit_button = $Panel/VBox/QuitButton

func _ready() -> void:
	continue_button.pressed.connect(close)
	deck_button.pressed.connect(_on_deck)
	quit_button.pressed.connect(_on_quit)
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if _is_menu_pressed(event):
		if visible:
			close()
		else:
			open()

func open() -> void:
	_clock_was_visible = GameState.clock_visible
	_status_was_visible = GameState.youns_status_visible
	GameState.set_clock_visible(false)
	GameState.set_clock_paused(true)
	GameState.set_youns_status_visible(false)
	show()
	get_tree().paused = true

func close() -> void:
	GameState.set_clock_paused(false)
	GameState.set_clock_visible(_clock_was_visible)
	GameState.set_youns_status_visible(_status_was_visible)
	hide()
	get_tree().paused = false

func _on_deck() -> void:
	close()
	get_tree().change_scene_to_file("res://features/deck_builder/ui/deck_builder_screen.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()

func _is_menu_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("menu_toggle"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true
