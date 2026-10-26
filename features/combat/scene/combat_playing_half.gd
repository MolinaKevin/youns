class_name CombatPlayingHalf
extends RefCounted

## Mitad de carta (o comodín) que el jugador está jugando esta ronda. Antes
## era un Dictionary sin esquema (CombatTurnController.playing) leído por
## nombre de clave desde varios archivos del combate; un typo de clave fallaba
## en silencio en vez de marcarlo el chequeo estático. null = no hay ninguna
## mitad en curso (antes era el Dictionary vacío).

var card: int = -1
var is_top: bool = false
var lines: Array = []
var index: int = 0
var started: bool = false
var active: bool = false
var wild: bool = false
var source: CardAction = null
var used: int = 0
var cap: int = -1
## Último índice de línea ya contado para gastar un uso de la mitad (-1 = ninguno).
var counted: int = -1
