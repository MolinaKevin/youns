class_name AiCondition
extends Resource

## Constantes para comparar type sin escribir el string a mano (ver
## AiAction.TYPE_* / CardActionLine para el mismo criterio).
const TYPE_ALWAYS := "always"
const TYPE_PLAYER_ADJACENT := "player_adjacent"
const TYPE_PLAYER_IN_RANGE := "player_in_range"
const TYPE_PLAYER_OUT_OF_RANGE := "player_out_of_range"
const TYPE_PLAYER_FAR := "player_far"
const TYPE_SELF_HP_LOW := "self_hp_low"
const TYPE_SELF_HP_CRITICAL := "self_hp_critical"
const TYPE_HAS_LOS := "has_los"
const TYPE_PLAYER_HIDDEN := "player_hidden"

## Tipos soportados:
##   always            — siempre true
##   player_adjacent   — jugador a distancia <= range
##   player_in_range   — jugador en range Y con LOS
##   player_out_of_range — jugador fuera de range O sin LOS
##   player_far        — jugador a más de 15 unidades
##   self_hp_low       — HP propio < 30%
##   self_hp_critical  — HP propio < 15%
##   has_los           — hay línea de visión al jugador
##   player_hidden     — tenía LOS antes pero ahora no

@export var type: String = TYPE_ALWAYS
@export var check_range: float = 12.0
