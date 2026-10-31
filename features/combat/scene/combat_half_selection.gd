class_name CombatHalfSelection
extends RefCounted

## Mitad de carta reservada por un comodín. Evita que KEEP e ITEM dependan de
## diccionarios con las mismas claves mágicas en distintos widgets.

var card_index := -1
var is_top := false


static func make(p_card_index: int, p_is_top: bool) -> CombatHalfSelection:
	var selection := CombatHalfSelection.new()
	selection.card_index = p_card_index
	selection.is_top = p_is_top
	return selection
