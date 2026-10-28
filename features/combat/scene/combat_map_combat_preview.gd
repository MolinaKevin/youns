class_name CombatMapCombatPreview
extends CombatMapCombatPreviewPort

var map: CombatMapArea
var overlay: CombatMapOverlay
var renderer: CombatMapRenderer

func show_push_enemy_selection(grab_range: float) -> void:
	renderer.show_disc(overlay.attack_disc, map.player_pos, grab_range + map.actors.state.geometry.player_radius())

func show_push_cone(origin: Vector2, direction: Vector2, push_range: float, half_angle: float) -> void:
	renderer.build_cone_disc(overlay.push_disc, origin, direction, push_range, half_angle)

func hide_attack_range() -> void:
	overlay.attack_disc.visible = false

func show_player_range(radius: float) -> void:
	renderer.show_disc(overlay.attack_disc, map.player_pos, radius)

func show_range_at(center: Vector2, radius: float) -> void:
	renderer.show_disc(overlay.attack_disc, center, radius)

func clear_module_selection() -> void:
	overlay.attack_disc.visible = false
	overlay.push_disc.visible = false
