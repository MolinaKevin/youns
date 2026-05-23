class_name AiAction
extends Resource

## Una acción que un enemigo puede ejecutar en su turno.
## Todas las conditions deben cumplirse para que la acción sea elegible.
## El evaluador elige la acción con mayor score entre las elegibles.

@export var action_type: String = "move_toward"
## Tipos soportados:
##   melee_attack      — ataca cuerpo a cuerpo
##   range_attack      — ataca a distancia si hay LOS
##   move_toward       — se acerca al jugador
##   move_away         — retrocede alejándose del jugador
##   move_to_last_known — se mueve a la última posición conocida del jugador
##   block             — gana block_amount de bloqueo

@export var base_score: float = 50.0
@export var conditions: Array[AiCondition] = []

# ── Parámetros de la acción ───────────────────────────────────────────────────

@export var damage: int = 0
@export var move_range: float = 5.0
@export var block_amount: int = 0

# ── Modificadores de score ────────────────────────────────────────────────────

@export var score_multiplier_low_hp: float = 1.0
## Multiplica base_score cuando el enemigo tiene < 30% de HP.
## > 1.0 → prioriza esta acción cuando está débil.
## < 1.0 → la evita cuando está débil.
