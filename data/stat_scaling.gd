extends Resource
class_name StatScaling

## Un valor de carta que escala con una o dos estadísticas del Youn:
##   valor = base + factor × estadística + factor_2 × estadística_2
## Con stat = "ninguna" ese término no suma. "peso" es el peso actual del Youn
## (no es una de las 8 estadísticas, pero se puede usar igual).

@export var base: int = 0
@export_enum("ninguna", "constitucion", "mente", "fuerza", "resistencia",
	"agilidad", "tecnica", "inteligencia", "espiritu", "peso") var stat: String = "ninguna"
@export var factor: float = 0.0
@export_enum("ninguna", "constitucion", "mente", "fuerza", "resistencia",
	"agilidad", "tecnica", "inteligencia", "espiritu", "peso") var stat_2: String = "ninguna"
@export var factor_2: float = 0.0

## stats: {"fuerza": 50, "peso": 12.0, ...} (claves de YounStats.KEYS más
## "peso"). Nunca devuelve negativo.
func evaluate(stats: Dictionary) -> int:
	var value := float(base)
	if stat != "ninguna":
		value += factor * float(stats.get(stat, 0))
	if stat_2 != "ninguna":
		value += factor_2 * float(stats.get(stat_2, 0))
	return maxi(0, roundi(value))
