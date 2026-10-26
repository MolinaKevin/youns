class_name CombatMapArea
extends Node3D

## Contrato mínimo que necesita la IA enemiga del tablero de combate.
##
## MapArea lo implementa en juego y CombatTestCase.MockMapArea en los tests.
## Mantener este borde chico evita que la IA dependa de la escena concreta ni
## obligue a los tests unitarios a instanciar geometría, actores o renderer.

const WORLD_W := 30.0
const WORLD_H := 30.0

var player_pos := Vector2.ZERO
var enemy_pos := Vector2.ZERO
var queries: Variant
var movement: Variant
var interactions: Variant
