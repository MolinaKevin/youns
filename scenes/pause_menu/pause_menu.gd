extends CanvasLayer

var enabled := false

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
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open()

func open() -> void:
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = false

func _on_deck() -> void:
	close()
	get_tree().change_scene_to_file("res://UI/DeckBuilder/deck_builder_screen.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()
