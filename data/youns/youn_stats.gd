class_name YounStats
extends Resource

## Las 8 estadísticas de un Youn. Se usa para las estadísticas BASE de cada
## YounData; los valores actuales de la partida viven en PlayerSaveData
## (ver YounStatRules).
##   vitalidad    — vida
##   energia      — reserva para técnicas y habilidades (todavía sin uso)
##   fuerza       — daño físico, empujes
##   resistencia  — defensa, escudos, resistencia a estados
##   agilidad     — movimiento, iniciativa
##   tecnica      — distancia, alcance, combos
##   inteligencia — tamaño de mano, áreas, duración de estados
##   espiritu     — poder elemental, curación, buffs

const KEYS: Array[String] = [
	"vitalidad", "energia", "fuerza", "resistencia",
	"agilidad", "tecnica", "inteligencia", "espiritu",
]

@export var vitalidad: int = 0
@export var energia: int = 0
@export var fuerza: int = 0
@export var resistencia: int = 0
@export var agilidad: int = 0
@export var tecnica: int = 0
@export var inteligencia: int = 0
@export var espiritu: int = 0

func to_dict() -> Dictionary:
	var result := {}
	for key in KEYS:
		result[key] = int(get(key))
	return result
