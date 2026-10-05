extends Resource
class_name CardAction

## Una mitad de carta (superior o inferior): una lista de líneas de acción que
## se ejecutan una después de la otra.
@export var lines: Array[CardActionLine] = []
## Color de la mitad: es su fondo en la carta. Cada mitad tiene el suyo, así una
## carta armada con mitades de otras cartas puede quedar de varios colores.
@export var color: Color = Color(0.07, 0.16, 0.24)
## Inteligencia de la mitad (ids de Intelligences). La pone una evolución al
## recolorearla (y entonces `color` es el de esa inteligencia); vacío = sin
## inteligencia (la carta como vino).
@export var intelligence: String = ""

## Copia propia de la mitad, con copias de sus líneas: para modificarla (en el
## mazo de una partida) sin tocar la carta original.
func clone() -> CardAction:
	var copy: CardAction = duplicate()
	var copied_lines: Array[CardActionLine] = []
	for line in lines:
		copied_lines.append(line.duplicate() if line != null else null)
	copy.lines = copied_lines
	return copy

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
