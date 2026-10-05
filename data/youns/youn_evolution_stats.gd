class_name YounEvolutionStats
extends Resource

## Qué le pasa a las 8 estadísticas actuales al evolucionar A este Youn
## (ver YounStatRules.apply_evolution).
##   SUMAR       — cada valor se suma a la actual (+20 fuerza).
##   MULTIPLICAR — cada valor es un factor sobre la actual (0.8 = queda el 80%).
##                 Ojo: un factor en 0 deja la estadística en 0; poner 1.0 para
##                 no tocarla.
## El resultado se redondea y nunca baja de 0.

enum Mode { SUMAR, MULTIPLICAR }

@export var mode: Mode = Mode.SUMAR

@export var constitucion: float = 0.0
@export var mente: float = 0.0
@export var fuerza: float = 0.0
@export var resistencia: float = 0.0
@export var agilidad: float = 0.0
@export var tecnica: float = 0.0
@export var inteligencia: float = 0.0
@export var espiritu: float = 0.0

## Aplica la evolución sobre las estadísticas actuales ({"fuerza": 50, ...}).
func apply_to(stats: Dictionary) -> Dictionary:
	var result := {}
	for key in YounStats.KEYS:
		var value := float(stats.get(key, 0))
		var amount := float(get(key))
		if mode == Mode.MULTIPLICAR:
			value *= amount
		else:
			value += amount
		result[key] = maxi(0, roundi(value))
	return result
