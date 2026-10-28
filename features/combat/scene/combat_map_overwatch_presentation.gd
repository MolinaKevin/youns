class_name CombatMapOverwatchPresentation
extends CombatMapOverwatchPort

var overlay: CombatMapOverlay
var renderer: CombatMapRenderer

func show_preview(origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> void:
	var preview := overlay.overwatch_preview_disc
	preview.set_meta("fill_mat", overlay.make_material(Color(1.0, 0.85, 0.1, 0.20)))
	preview.set_meta("bord_mat", overlay.make_material(Color(1.0, 1.0, 0.35, 0.55)))
	renderer.build_cone_disc(preview, origin, direction, cone_range, half_angle)
	preview.visible = true

func hide_preview() -> void:
	overlay.overwatch_preview_disc.visible = false

func show_zone(origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> void:
	var zone := overlay.overwatch_zone
	zone.set_meta("fill_mat", overlay.make_material(Color(1.0, 0.85, 0.1, 0.22)))
	zone.set_meta("bord_mat", overlay.make_material(Color(1.0, 1.0, 0.35, 0.70)))
	renderer.build_cone_disc(zone, origin, direction, cone_range, half_angle)

func clear_zone() -> void:
	overlay.overwatch_zone.visible = false
