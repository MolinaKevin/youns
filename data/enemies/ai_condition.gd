class_name AiCondition
extends Resource

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

@export var type: String = "always"
@export var check_range: float = 12.0
