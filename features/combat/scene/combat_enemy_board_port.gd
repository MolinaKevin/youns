class_name CombatEnemyBoardPort
extends RefCounted

var state: CombatEnemyBoardStateAdapter
var queries: CombatEnemyBoardQueriesAdapter
var effects: CombatEnemyBoardEffectsAdapter
var movement: CombatEnemyBoardMovementAdapter

## Contrato mínimo que necesita la IA enemiga para decidir y ejecutar un turno.
## No expone las fachadas generales del mapa: cada operación representa una
## necesidad concreta de la IA, lo que permite probarla sin una escena 3D.
