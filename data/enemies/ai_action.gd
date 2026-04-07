class_name AiAction
extends Resource

## Una acción que un enemigo puede ejecutar en su turno.
## Todas las conditions deben cumplirse para que la acción sea elegible.
## El evaluador elige la acción con mayor score entre las elegibles.

@export var action_type: String = "move_toward"
## Tipos soportados:
##   melee_attack  — ataca si el jugador está dentro de attack_range
##   range_attack  — ataca a distancia si hay LOS y jugador en attack_range
##   move_toward   — se acerca al jugador
##   move_away     — retrocede alejándose del jugador
##   block         — gana block_amount de bloqueo

@export var base_score: float = 50.0
## Score base de esta acción. La acción elegible con mayor score gana.

@export var conditions: Array = []
## Lista de condiciones (strings). TODAS deben cumplirse.
## Valores disponibles:
##   "always"            — siempre true
##   "player_adjacent"   — jugador a distancia <= attack_range
##   "player_in_range"   — jugador en attack_range Y con LOS
##   "player_out_of_range" — jugador fuera de attack_range O sin LOS
##   "player_far"        — jugador a más de 15 unidades
##   "self_hp_low"       — HP propio <= 30%
##   "self_hp_critical"  — HP propio <= 15%
##   "has_los"           — hay línea de visión al jugador

# ── Parámetros de la acción ───────────────────────────────────────────────────

@export var damage: int = 0
@export var attack_range: float = 2.0
@export var move_range: float = 5.0
@export var block_amount: int = 0

# ── Modificadores de score ────────────────────────────────────────────────────

@export var score_multiplier_low_hp: float = 1.0
## Multiplica base_score cuando el enemigo tiene <= 30% de HP.
## > 1.0 → prioriza esta acción cuando está débil.
## < 1.0 → la evita cuando está débil.
