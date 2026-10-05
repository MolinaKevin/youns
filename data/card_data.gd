extends Resource
class_name CardData

@export var id: String
@export var name: String
@export var image: Texture2D
## Menor iniciativa actúa primero.
@export var initiative: int = 50
@export var top: CardAction
@export var bottom: CardAction

## Copia propia de la carta y de sus dos mitades (con sus líneas): el mazo de
## cada partida guarda copias así, para que las evoluciones puedan cambiarlas.
func clone() -> CardData:
	var copy: CardData = duplicate()
	copy.top = top.clone() if top != null else null
	copy.bottom = bottom.clone() if bottom != null else null
	return copy

func get_action(is_top: bool) -> CardAction:
	var action: CardAction = top if is_top else bottom
	if action != null:
		for line in action.lines:
			if line != null:
				line.name = name
	return action
