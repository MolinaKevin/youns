class_name YounStats
extends Resource

## Las 8 estadísticas de un Youn. Se usa para las estadísticas BASE de cada
## YounData; los valores actuales de la partida viven en PlayerSaveData
## (ver YounStatRules).
##   constitucion — vida (ver YounStatRules.max_hp) y golpes con el cuerpo (salto)
##   mente        — MP: la reserva que gastan las líneas con costo (ver YounStatRules.max_mp)
##   fuerza       — daño físico, empujes
##   resistencia  — defensa física (bloqueo), resistencia a estados
##   agilidad     — movimiento, iniciativa
##   tecnica      — distancia, alcance, combos
##   inteligencia — escudo mágico, tamaño de mano, áreas, duración de estados
##   espiritu     — daño mágico, poder elemental, curación, buffs

const KEYS: Array[String] = [
	"constitucion", "mente", "fuerza", "resistencia",
	"agilidad", "tecnica", "inteligencia", "espiritu",
]

@export var constitucion: int = 0
@export var mente: int = 0
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
