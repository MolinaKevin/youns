class_name NpcChoice
extends Resource

## Vacío = usa LocalizationState.item_name(give_item.id, give_item.name) —
## para "dar un ítem" no hace falta repetir su nombre acá. Hace falta esta
## clave solo si la opción no entrega un ítem (ej. "Descansar") o si el texto
## del botón debe ser distinto al nombre real del ítem.
@export var label_key: String = ""
## Vacío = la opción no entrega ningún ítem.
@export var give_item: ItemData = null
@export var restore_energy: bool = false
## true = elegir esta opción arranca un combate (ver world_youn.gd).
@export var starts_combat: bool = false

func label() -> String:
	if not label_key.is_empty():
		return LocalizationState.t(label_key)
	if give_item != null:
		return LocalizationState.item_name(give_item.id, give_item.name)
	return ""
