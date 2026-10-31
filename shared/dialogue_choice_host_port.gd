class_name DialogueChoiceHostPort
extends RefCounted

## Puerto mínimo que necesita el menú de elecciones. Evita que la lógica de
## navegación dependa de la escena concreta DialogueBox.

signal choice_made(index: int)

func open_choice_menu() -> void: pass
func close_choice_menu() -> void: pass
func add_choice_button(_button: Button) -> void: pass
func resolve_choice(index: int) -> void: choice_made.emit(index)
