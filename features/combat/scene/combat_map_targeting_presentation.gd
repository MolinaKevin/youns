class_name CombatMapTargetingPresentation
extends CombatMapTargetingPresentationPort

var map: CombatMapArea
var visual_overlay: CombatMapOverlay
var renderer: CombatMapRenderer
var range_overlay: CombatRangeOverlay

func _init() -> void:
	overlay = CombatMapTargetingOverlayAdapter.new(self)
	hover = CombatMapTargetingHoverAdapter.new(self)

func show_move_selection(cells: Array[Vector2i]) -> void:
	range_overlay.build_cells_on_terrain(visual_overlay.move_disc, cells)
	renderer.show_footprint(visual_overlay.player_circle, map.player_pos, map.actors.state.geometry.player_radius(), map.HIGHLIGHT_Y)

func clear_move_selection() -> void:
	visual_overlay.move_disc.visible = false
	visual_overlay.player_circle.visible = false

func show_move_preview(pos: Vector2) -> void:
	renderer.show_disc(visual_overlay.dest_marker, pos, 0.5)

func clear_move_preview() -> void:
	visual_overlay.dest_marker.visible = false

func show_path_preview() -> void:
	range_overlay.render_path_preview(visual_overlay.path_highlight, map.terrain.navigation.planned_path())

func clear_path_preview() -> void:
	visual_overlay.path_highlight.visible = false

func show_attack_selection(attack_range: float) -> void:
	# Temporal: los alcances amplios no necesitan una malla por celda. El disco
	# continuo evita bloquear un frame mientras revisamos el renderer granular.
	renderer.show_simple_disc(visual_overlay.attack_disc, map.player_pos, attack_range + map.actors.state.geometry.player_radius())
	renderer.show_footprint(visual_overlay.enemy_hover, map.enemy_pos, map.actors.state.geometry.enemy_radius(), map.HOVER_Y)
	visual_overlay.enemy_hover.visible = false

func clear_attack_selection() -> void:
	visual_overlay.attack_disc.visible = false
	visual_overlay.enemy_hover.visible = false

func show_enemy_highlight() -> void:
	renderer.show_footprint(visual_overlay.enemy_highlight, map.enemy_pos, map.actors.state.geometry.enemy_radius(), map.HIGHLIGHT_Y)
	renderer.show_footprint(visual_overlay.enemy_hover, map.enemy_pos, map.actors.state.geometry.enemy_radius(), map.HOVER_Y)
	visual_overlay.enemy_hover.visible = false

func clear_enemy_highlight() -> void:
	visual_overlay.enemy_highlight.visible = false
	visual_overlay.enemy_hover.visible = false

func show_self_highlight() -> void:
	renderer.show_footprint(visual_overlay.self_highlight, map.player_pos, map.actors.state.geometry.player_radius(), map.HIGHLIGHT_Y)
	renderer.show_footprint(visual_overlay.self_hover, map.player_pos, map.actors.state.geometry.player_radius(), map.HOVER_Y)
	visual_overlay.self_hover.visible = false

func clear_self_highlight() -> void:
	visual_overlay.self_highlight.visible = false
	visual_overlay.self_hover.visible = false

func has_active_targeting_overlay() -> bool:
	return visual_overlay.move_disc.visible or visual_overlay.attack_disc.visible or visual_overlay.push_disc.visible or visual_overlay.push_enemy_disc.visible \
		or visual_overlay.enemy_highlight.visible or visual_overlay.self_highlight.visible

func has_enemy_targeting_overlay() -> bool:
	return visual_overlay.enemy_highlight.visible or visual_overlay.attack_disc.visible

func has_self_targeting_overlay() -> bool:
	return visual_overlay.self_highlight.visible

func update_targeting_hover(pos: Vector2, enemy_hover: bool, self_hover: bool, show_cell: bool) -> void:
	if show_cell:
		var center := renderer.visual_cell_center(pos)
		renderer.show_single_cell(visual_overlay.hover_cell, center, map.terrain.geometry.bounds.height_at(center))
	else:
		visual_overlay.hover_cell.visible = false
		visual_overlay.enemy_hover.visible = enemy_hover
		visual_overlay.self_hover.visible = self_hover

func clear_targeting_hover() -> void:
	visual_overlay.hover_cell.visible = false
	visual_overlay.enemy_hover.visible = false
	visual_overlay.self_hover.visible = false
	visual_overlay.overwatch_preview_disc.visible = false
