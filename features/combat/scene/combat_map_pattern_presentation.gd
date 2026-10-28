class_name CombatMapPatternPresentation
extends CombatMapPatternPort

var overlay: CombatMapOverlay
var renderer: CombatMapRenderer

func show_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> void:
	if pattern == null or pattern.shape == "none": return
	var preview := overlay.card_pattern_preview
	preview.set_meta("fill_mat", overlay.make_material(Color(0.95, 0.65, 0.15, 0.22)))
	preview.set_meta("bord_mat", overlay.make_material(Color(1.0, 0.82, 0.3, 0.72)))
	var normalized := direction.normalized() if direction.length() > 0.001 else Vector2(0, 1)
	match pattern.shape:
		"circle": renderer.build_tile_disc(preview, origin, primary, 0.0, 0.025)
		"cone": renderer.build_cone_disc(preview, origin, normalized, primary, pattern.cone_half_angle)
		"line": renderer.build_line_pattern(preview, origin, normalized, primary, float(pattern.secondary_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL, float(pattern.start_offset_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL, overlay.make_material(Color(0.95, 0.65, 0.15, 0.35)))

func clear_card_pattern() -> void:
	overlay.card_pattern_preview.visible = false
