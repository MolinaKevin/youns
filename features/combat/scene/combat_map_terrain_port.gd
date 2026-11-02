class_name CombatMapTerrainPort
extends RefCounted

var navigation: CombatMapTerrainNavigationPort
var geometry: CombatMapTerrainGeometryPort = CombatMapTerrainGeometryPort.new()
var mutation: CombatMapTerrainMutationAdapter = CombatMapTerrainMutationAdapter.new()

func obstacles() -> Array[Dictionary]: return []

## Puertos pequeños para geometría, navegación y mutaciones del terreno.
