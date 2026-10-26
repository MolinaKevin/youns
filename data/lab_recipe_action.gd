class_name LabRecipeAction
extends RefCounted

## Tipos de acción que pueden declarar las recetas del laboratorio.
## Los recursos .tres conservan strings para editarse en el Inspector; el
## código usa estas constantes para mantener un solo contrato.
const INSTANT := "instant"
const LOOP := "loop"
const UPGRADE := "upgrade"
const NEXT := "next"
const DUNGEON := "dungeon"

const TYPES := [INSTANT, LOOP, UPGRADE, NEXT, DUNGEON]


static func is_known(action_type: String) -> bool:
	return action_type in TYPES
