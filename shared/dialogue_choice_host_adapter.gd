class_name DialogueChoiceHostAdapter
extends DialogueChoiceHostPort

## Adaptador del autoload Dialogue al puerto de DialogueChoiceMenu.

var _dialogue: CanvasLayer


func _init(dialogue: CanvasLayer) -> void:
	_dialogue = dialogue
	_dialogue.choice_made.connect(func(index: int) -> void: choice_made.emit(index))


func open_choice_menu() -> void:
	_dialogue.open_choice_menu()


func close_choice_menu() -> void:
	_dialogue.close_choice_menu()


func add_choice_button(button: Button) -> void:
	_dialogue.add_choice_button(button)


func resolve_choice(index: int) -> void:
	_dialogue.resolve_choice(index)
