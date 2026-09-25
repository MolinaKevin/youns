class_name CombatState
extends RefCounted

## Vida, daño, bloqueo y curación usan números grandes (x10 respecto de la
## primera versión) para que después puedan escalar con estadísticas.
const BURN_DAMAGE := 30              # por turno en llamas
const BLEED_DAMAGE := 20             # por turno sangrando
const POISON_DAMAGE_PER_STACK := 10  # el veneno pega acumulaciones x esto

var player_hp := 400
var player_block := 0

var enemy_hp := 350
var enemy_max_hp := 350
var enemy_block := 0

var player_wet_turns: int = 0
var enemy_wet_turns:  int = 0
var player_burning_turns: int = 0
var enemy_burning_turns: int = 0
var player_greasy_turns: int = 0
var enemy_greasy_turns: int = 0
var player_entangled_turns: int = 0
var enemy_entangled_turns: int = 0
var player_bleeding_turns: int = 0
var enemy_bleeding_turns: int = 0
var player_poison_stacks: int = 0
var enemy_poison_stacks: int = 0
var player_blinded_turns: int = 0
var enemy_blinded_turns: int = 0
var player_frozen_turns: int = 0
var enemy_frozen_turns:  int = 0

var player_overwatch_active:     bool    = false
var player_overwatch_origin:     Vector2 = Vector2.ZERO
var player_overwatch_dir:        Vector2 = Vector2.ZERO
var player_overwatch_range:      float   = 0.0
var player_overwatch_half_angle: float   = 45.0
var player_overwatch_damage:     int     = 0

var hand: Array = []
## Las dos mitades elegidas este turno (superior de una carta, inferior de la otra).
var turn_actions: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
