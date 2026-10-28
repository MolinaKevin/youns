class_name CombatEnemyBoardPort
extends RefCounted

var state: CombatEnemyBoardStatePort = CombatEnemyBoardStatePort.new()
var queries: CombatEnemyBoardQueriesPort = CombatEnemyBoardQueriesPort.new()
var effects: CombatEnemyBoardEffectsPort = CombatEnemyBoardEffectsPort.new()
var movement: CombatEnemyBoardMovementPort = CombatEnemyBoardMovementPort.new()

## Contrato mínimo que necesita la IA enemiga para decidir y ejecutar un turno.
## No expone las fachadas generales del mapa: cada operación representa una
## necesidad concreta de la IA, lo que permite probarla sin una escena 3D.
