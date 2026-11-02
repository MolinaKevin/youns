class_name CombatMapEffectsPort
extends RefCounted

var traps: CombatMapTrapEffectsAdapter
var puddle_port: CombatMapPuddleEffectsAdapter
var delayed: CombatMapDelayedEffectsAdapter


## Efectos persistentes o transitorios del tablero que consumen las acciones.
## No expone sistemas concretos ni escenas: sólo operaciones de gameplay.
