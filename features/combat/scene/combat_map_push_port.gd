class_name CombatMapPushPort
extends RefCounted

var selection: CombatMapPushSelectionPort = CombatMapPushSelectionPort.new()
var queries: CombatMapPushQueriesPort = CombatMapPushQueriesPort.new()
var execution: CombatMapPushExecutionPort = CombatMapPushExecutionPort.new()
var modules: CombatMapPushModulesPort = CombatMapPushModulesPort.new()

## Empujes, arrastres y conos de dirección del tablero.
