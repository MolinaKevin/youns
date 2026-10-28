class_name CombatMapSelectionPort
extends RefCounted

var targeting: CombatMapSelectionTargetingPort = CombatMapSelectionTargetingPort.new()
var actions: CombatMapSelectionActionsPort = CombatMapSelectionActionsPort.new()

## Puerto de los modos de selección y sus previews.
## La ejecución de colocaciones (trampas, granadas y charcos) vive en
## CombatMapPlacementPort; no se hereda ese contrato acá.
