class_name CombatMapPresentation
extends "res://features/combat/scene/combat_map_presentation_port.gd"

## Fachada visual de MapArea. Los sistemas de combate piden intenciones de UI
## aquí, sin conocer los MeshInstance3D que forman el overlay.
var map: CombatMapArea
var overlay: CombatMapOverlay
var renderer: CombatMapRenderer
var range_overlay: CombatRangeOverlay
var actor_presentation: CombatActorPresentation
var pattern_presentation := CombatMapPatternPresentation.new()
var targeting_presentation := CombatMapTargetingPresentation.new()
var overlay_presentation := CombatMapOverlayPresentation.new()
var combat_preview_presentation := CombatMapCombatPreview.new()
var overwatch_presentation := CombatMapOverwatchPresentation.new()

func _init() -> void:
	patterns = pattern_presentation
	targeting = targeting_presentation
	overlay_port = overlay_presentation
	combat_preview = combat_preview_presentation
	overwatch = overwatch_presentation
