extends Resource
class_name StatScaling

## Un valor de carta que escala con una estadística del Youn:
##   valor = base + factor × estadística
## Con stat = "ninguna" el valor es solo la base.

@export var base: int = 0
@export_enum("ninguna", "vitalidad", "energia", "fuerza", "resistencia",
	"agilidad", "tecnica", "inteligencia", "espiritu") var stat: String = "ninguna"
@export var factor: float = 0.0

## stats: {"fuerza": 50, ...} (claves de YounStats.KEYS). Nunca devuelve negativo.
func evaluate(stats: Dictionary) -> int:
	var value := float(base)
	if stat != "ninguna":
		value += factor * float(stats.get(stat, 0))
	return maxi(0, roundi(value))
