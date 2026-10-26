class_name CombatMapPresentation
extends RefCounted

## Fachada visual de MapArea. Los sistemas de combate piden intenciones de UI
## aquí, sin conocer los MeshInstance3D que forman el overlay.
var map: MapArea
var overlay: CombatMapOverlay

func make_material(color: Color) -> StandardMaterial3D:
	return map.make_mat(color)

func make_disc(color: Color) -> MeshInstance3D:
	return map.make_disc(color)

func show_disc(mesh: MeshInstance3D, center: Vector2, radius: float) -> void:
	map.show_disc(mesh, center, radius)

func show_simple_disc(mesh: MeshInstance3D, center: Vector2, radius: float) -> void:
	map.show_simple_disc(mesh, center, radius)

func show_disc_with_los(mesh: MeshInstance3D, origin: Vector2, radius: float, elevation: int = 0) -> void:
	map.show_disc_with_los(mesh, origin, radius, elevation)

func build_tile_disc(mesh: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, y: float, exclusions: Array = []) -> void:
	map.build_tile_disc(mesh, center, radius, inner_radius, y, exclusions)

func show_move_selection(cells: Array[Vector2i]) -> void:
	map.build_cells_on_terrain(overlay.move_disc, cells)
	map.show_footprint(overlay.player_circle, map.player_pos, map.actors.player_radius())

func clear_move_selection() -> void:
	overlay.move_disc.visible = false
	overlay.player_circle.visible = false

func show_move_preview(pos: Vector2) -> void:
	map.show_disc(overlay.dest_marker, pos, 0.5)

func clear_move_preview() -> void:
	overlay.dest_marker.visible = false

func show_path_preview() -> void:
	map.render_path_preview()

func clear_path_preview() -> void:
	overlay.path_highlight.visible = false

func show_attack_selection(attack_range: float) -> void:
	map.show_disc(overlay.attack_disc, map.player_pos, attack_range + map.actors.player_radius())
	map.show_footprint(overlay.enemy_hover, map.enemy_pos, map.actors.enemy_radius(), map.HOVER_Y)
	overlay.enemy_hover.visible = false

func clear_attack_selection() -> void:
	overlay.attack_disc.visible = false
	overlay.enemy_hover.visible = false

func show_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> void:
	if pattern == null or pattern.shape == "none": return
	var preview := overlay.card_pattern_preview
	preview.set_meta("fill_mat", map.make_mat(Color(0.95, 0.65, 0.15, 0.22)))
	preview.set_meta("bord_mat", map.make_mat(Color(1.0, 0.82, 0.3, 0.72)))
	var normalized := direction.normalized() if direction.length() > 0.001 else Vector2(0, 1)
	match pattern.shape:
		"circle": map.build_tile_disc(preview, origin, primary, 0.0, 0.025)
		"cone": map.build_cone_disc(preview, origin, normalized, primary, pattern.cone_half_angle)
		"line": map.build_line_pattern(preview, origin, normalized, primary, float(pattern.secondary_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL, float(pattern.start_offset_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL)

func clear_card_pattern() -> void:
	overlay.card_pattern_preview.visible = false

func show_enemy_highlight() -> void:
	map.show_footprint(overlay.enemy_highlight, map.enemy_pos, map.actors.enemy_radius())
	map.show_footprint(overlay.enemy_hover, map.enemy_pos, map.actors.enemy_radius(), map.HOVER_Y)
	overlay.enemy_hover.visible = false

func clear_enemy_highlight() -> void:
	overlay.enemy_highlight.visible = false
	overlay.enemy_hover.visible = false

func show_self_highlight() -> void:
	map.show_footprint(overlay.self_highlight, map.player_pos, map.actors.player_radius())
	map.show_footprint(overlay.self_hover, map.player_pos, map.actors.player_radius(), map.HOVER_Y)
	overlay.self_hover.visible = false

func clear_self_highlight() -> void:
	overlay.self_highlight.visible = false
	overlay.self_hover.visible = false

func has_active_targeting_overlay() -> bool:
	return overlay.move_disc.visible or overlay.attack_disc.visible or overlay.push_disc.visible or overlay.push_enemy_disc.visible \
		or overlay.enemy_highlight.visible or overlay.self_highlight.visible

func has_enemy_targeting_overlay() -> bool:
	return overlay.enemy_highlight.visible or overlay.attack_disc.visible

func has_self_targeting_overlay() -> bool:
	return overlay.self_highlight.visible

func update_targeting_hover(pos: Vector2, enemy_hover: bool, self_hover: bool, show_cell: bool) -> void:
	if show_cell:
		map.show_single_cell(overlay.hover_cell, pos)
	else:
		overlay.hover_cell.visible = false
	overlay.enemy_hover.visible = enemy_hover
	overlay.self_hover.visible = self_hover

func clear_targeting_hover() -> void:
	overlay.hover_cell.visible = false
	overlay.enemy_hover.visible = false
	overlay.self_hover.visible = false
	overlay.overwatch_preview_disc.visible = false

func show_push_enemy_selection(grab_range: float) -> void:
	map.show_disc(overlay.attack_disc, map.player_pos, grab_range + map.actors.player_radius())

func show_push_cone(origin: Vector2, direction: Vector2, push_range: float, half_angle: float) -> void:
	map.build_cone_disc(overlay.push_disc, origin, direction, push_range, half_angle)

func clear_push_selection() -> void:
	overlay.push_disc.visible = false
	overlay.push_enemy_disc.visible = false
	overlay.attack_disc.visible = false

func hide_attack_range() -> void:
	overlay.attack_disc.visible = false

func show_player_range(radius: float) -> void:
	map.show_disc(overlay.attack_disc, map.player_pos, radius)

func show_range_at(center: Vector2, radius: float) -> void:
	map.show_disc(overlay.attack_disc, center, radius)

func clear_module_selection() -> void:
	overlay.attack_disc.visible = false
	overlay.push_disc.visible = false

func show_overwatch_preview(origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> void:
	var preview := overlay.overwatch_preview_disc
	preview.set_meta("fill_mat", map.make_mat(Color(1.0, 0.85, 0.1, 0.20)))
	preview.set_meta("bord_mat", map.make_mat(Color(1.0, 1.0, 0.35, 0.55)))
	map.build_cone_disc(preview, origin, direction, cone_range, half_angle)
	preview.visible = true

func hide_overwatch_preview() -> void:
	overlay.overwatch_preview_disc.visible = false

func show_overwatch_zone(origin: Vector2, direction: Vector2, cone_range: float, half_angle: float) -> void:
	var zone := overlay.overwatch_zone
	zone.set_meta("fill_mat", map.make_mat(Color(1.0, 0.85, 0.1, 0.22)))
	zone.set_meta("bord_mat", map.make_mat(Color(1.0, 1.0, 0.35, 0.70)))
	map.build_cone_disc(zone, origin, direction, cone_range, half_angle)

func clear_overwatch_zone() -> void:
	overlay.overwatch_zone.visible = false

## Las etiquetas acompañan a los actores durante sus animaciones. Queda en la
## fachada visual, no en el nodo dueño del combate.
func place_status_labels() -> void:
	map.place_status_labels()
