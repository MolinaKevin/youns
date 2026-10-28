class_name CombatMapActorsPort
extends RefCounted

var presentation: CombatMapActorPresentationPort = CombatMapActorPresentationPort.new()
var movement: CombatMapActorMovementPort = CombatMapActorMovementPort.new()
var state: CombatMapActorStatePort = CombatMapActorStatePort.new()

## Contrato compuesto para los actores del tablero. Las operaciones concretas
## viven en los puertos de estado, presentación y movimiento.
