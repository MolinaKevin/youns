class_name AiAction
extends Resource

## Una acción que un enemigo puede ejecutar en su turno.
## Todas las conditions deben cumplirse para que la acción sea elegible.
## El evaluador elige la acción con mayor score entre las elegibles.

## Constantes para comparar action_type sin escribir el string a mano: un typo
## en TYPE_MELEE_ATTACK es error de compilación, un typo en "melee_attack" no.
## El campo sigue siendo String (no un enum) para no tener que resavear los
## .tres de acciones. Mismo criterio que CardActionLine.
const TYPE_MELEE_ATTACK := "melee_attack"
const TYPE_RANGE_ATTACK := "range_attack"
const TYPE_MOVE_TOWARD := "move_toward"
const TYPE_MOVE_AWAY := "move_away"
const TYPE_MOVE_TO_LAST_KNOWN := "move_to_last_known"
const TYPE_BLOCK := "block"
const TYPE_WARD := "ward"

@export var action_type: String = TYPE_MOVE_TOWARD
## Tipos soportados:
##   melee_attack      — ataca cuerpo a cuerpo
##   range_attack      — ataca a distancia si hay LOS
##   move_toward       — se acerca al jugador
##   move_away         — retrocede alejándose del jugador
##   move_to_last_known — se mueve a la última posición conocida del jugador
##   block             — gana block_amount de bloqueo (frena daño físico)
##   ward              — gana block_amount de escudo mágico (frena daño mágico)

@export var base_score: float = 50.0
@export var conditions: Array[AiCondition] = []

# ── Parámetros de la acción ───────────────────────────────────────────────────

@export var damage: int = 0
## Físico lo frena el bloqueo; mágico, el escudo mágico.
@export_enum("fisico", "magico") var damage_type: String = "fisico"
@export var move_range: float = 5.0
@export var block_amount: int = 0

# ── Modificadores de score ────────────────────────────────────────────────────

@export var score_multiplier_low_hp: float = 1.0
## Multiplica base_score cuando el enemigo tiene < 30% de HP.
## > 1.0 → prioriza esta acción cuando está débil.
## < 1.0 → la evita cuando está débil.
