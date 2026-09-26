extends Resource
class_name CardAction

## Una mitad de carta (superior o inferior): una lista de líneas de acción que
## se ejecutan una después de la otra.
@export var lines: Array[CardActionLine] = []
## Color de la mitad: es su fondo en la carta. Cada mitad tiene el suyo, así una
## carta armada con mitades de otras cartas puede quedar de varios colores.
@export var color: Color = Color(0.07, 0.16, 0.24)

## Líneas que se pueden ejecutar, en orden.
func enabled_lines() -> Array[CardActionLine]:
	var result: Array[CardActionLine] = []
	for line in lines:
		if line != null and line.enabled:
			result.append(line)
	return result

## MP que cuesta jugar la mitad: la suma de sus líneas activas.
func mp_cost() -> int:
	var total := 0
	for line in enabled_lines():
		total += line.mp_cost
	return total
