extends Resource
class_name CardData

@export var id: String
@export var name: String
@export var image: Texture2D
## Menor iniciativa actúa primero.
@export var initiative: int = 50
@export var top: CardAction
@export var bottom: CardAction

func get_action(is_top: bool) -> CardAction:
	var action: CardAction = top if is_top else bottom
	if action != null:
		for line in action.lines:
			if line != null:
				line.name = name
	return action
