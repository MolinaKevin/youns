class_name CombatMovePlan
extends RefCounted

## Contrato de movimiento enemigo. La capa de puertos todavía serializa un
## Dictionary para no romper adaptadores existentes, pero la lógica central no
## depende de sus claves literales.

const DESTINATION := "destination"
const PATH := "path"

var destination := Vector2.ZERO
var path: Array[Vector2i] = []


static func make(p_destination: Vector2, p_path: Array[Vector2i]) -> CombatMovePlan:
	var plan := CombatMovePlan.new()
	plan.destination = p_destination
	plan.path = p_path
	return plan


static func parse(value: Dictionary) -> CombatMovePlan:
	if value.is_empty() or not value.get(DESTINATION) is Vector2:
		return null
	var cells: Array[Vector2i] = []
	for cell in value.get(PATH, []):
		if cell is Vector2i:
			cells.append(cell)
	return make(value[DESTINATION], cells)


func to_dictionary() -> Dictionary:
	return {DESTINATION: destination, PATH: path}
