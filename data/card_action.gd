extends Resource
class_name CardAction

const Intelligences := preload("res://data/youns/intelligences.gd")

## Una mitad de carta (superior o inferior): una lista de líneas de acción que
## se ejecutan una después de la otra.
@export var lines: Array[CardActionLine] = []
## Inteligencia de la mitad (ids de Intelligences): toda mitad tiene una.
## PLACEHOLDER: las cartas que todavía no fueron curadas a mano quedan con
## "linguistica" por defecto (ver docs/TODO.md).
@export var intelligence: String = Intelligences.IDS[0]

## Color de fondo de la mitad en la carta: siempre el de su inteligencia.
var color: Color:
	get: return Intelligences.half_color(intelligence)

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
