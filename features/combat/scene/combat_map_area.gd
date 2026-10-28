class_name CombatMapArea
extends Node3D

## Contrato mínimo que necesita la IA enemiga del tablero de combate.
##
## MapArea lo implementa en juego y CombatTestCase.MockMapArea en los tests.
## Mantener este borde chico evita que la IA dependa de la escena concreta ni
## obligue a los tests unitarios a instanciar geometría, actores o renderer.

const WORLD_W := 30.0
const WORLD_H := 30.0
## Separación mínima entre actores para aterrizajes y empujes.
const MIN_SEPARATION := 0.8
const AREA_CONTACT_FRACTION := 1.0 / 3.0
const HIGHLIGHT_Y := 0.03
const HOVER_Y := 0.04
const PLATFORM_HEIGHT := 1.5
const TREE_HEIGHT := 2.4
const CLICK_MARGIN := 0.6

var player_pos := Vector2.ZERO
var enemy_pos := Vector2.ZERO
var player_elevation: int = 0
var enemy_elevation: int = 0
## Fachadas del tablero. `MapArea` las compone con implementaciones reales;
## los dobles de prueba extienden estos tipos para conservar el contrato.
var queries: CombatMapQueries
var actors: CombatMapActors
var interactions: CombatMapInteractions
var presentation: CombatMapPresentation
var movement: CombatMapMovementPort
var terrain: CombatMapTerrainPort

func elevation_at(pos: Vector2) -> int:
	return terrain.elevation_at(pos)

func update_actor_positions() -> void:
	actors.sync_targets()
