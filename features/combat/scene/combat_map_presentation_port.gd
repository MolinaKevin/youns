class_name CombatMapPresentationPort
extends RefCounted

## Intenciones visuales requeridas por la resolución de cartas. Los meshes,
## overlays y el hover pertenecen a la implementación concreta.

var patterns: CombatMapPatternPort = CombatMapPatternPort.new()
var targeting: CombatMapTargetingPresentationPort = CombatMapTargetingPresentationPort.new()
var overlay_port: CombatMapOverlayPort = CombatMapOverlayPort.new()
var combat_preview: CombatMapCombatPreviewPort = CombatMapCombatPreviewPort.new()
var overwatch: CombatMapOverwatchPort = CombatMapOverwatchPort.new()
