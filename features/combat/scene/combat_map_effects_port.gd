class_name CombatMapEffectsPort
extends RefCounted

var traps: CombatMapTrapEffectsPort = CombatMapTrapEffectsPort.new()
var puddle_port: CombatMapPuddleEffectsPort = CombatMapPuddleEffectsPort.new()
var delayed: CombatMapDelayedEffectsPort = CombatMapDelayedEffectsPort.new()


## Efectos persistentes o transitorios del tablero que consumen las acciones.
## No expone sistemas concretos ni escenas: sólo operaciones de gameplay.
