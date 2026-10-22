class_name CombatTargeting
extends RefCounted

## Modos de selección y sus previsualizaciones. Usa a MapArea como fachada de
## terreno, navegación y overlay, sin ser dueño de esas reglas.
var map: Node
var selected_move_range := 0.0
var selected_attack_range := 0.0

func start_move_selection(move_range: float) -> void:
	selected_move_range = move_range
	var visible_cells: Array[Vector2i] = map._navigation.begin_move(map.player_pos, move_range, map.player_elevation,
		map._player_shadow_radius, map.enemy_pos, map._enemy_shadow_radius)
	map._build_cells_on_terrain(map._move_disc, visible_cells)
	map._show_footprint(map._player_circle, map.player_pos, map._player_shadow_radius)

func clear_move_selection() -> void:
	selected_move_range = 0.0
	map._move_disc.visible = false
	map._player_circle.visible = false

func show_move_preview(pos: Vector2) -> void:
	map._show_disc(map._dest_marker, pos, 0.5)

func clear_move_preview() -> void:
	map._dest_marker.visible = false

func show_path_preview() -> void:
	map._render_path_preview()

func clear_path_preview() -> void:
	map._path_highlight.visible = false

func start_attack_selection(attack_range: float) -> void:
	selected_attack_range = attack_range
	map._show_disc(map._attack_disc, map.player_pos, attack_range + map._player_shadow_radius)
	map._show_footprint(map._enemy_hover, map.enemy_pos, map._enemy_shadow_radius, map.HOVER_Y)
	map._enemy_hover.visible = false

func clear_attack_selection() -> void:
	selected_attack_range = 0.0
	map._attack_disc.visible = false
	map._enemy_hover.visible = false
	clear_card_pattern_preview()

func show_card_pattern_preview(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> void:
	if pattern == null or pattern.shape == "none":
		return
	map._card_pattern_preview.set_meta("fill_mat", map._make_mat(Color(0.95, 0.65, 0.15, 0.22)))
	map._card_pattern_preview.set_meta("bord_mat", map._make_mat(Color(1.0, 0.82, 0.3, 0.72)))
	var direction_normalized := direction.normalized() if direction.length() > 0.001 else Vector2(0, 1)
	match pattern.shape:
		"circle":
			map._build_tile_disc(map._card_pattern_preview, origin, primary, 0.0, 0.025)
		"cone":
			map._build_cone_disc(map._card_pattern_preview, origin, direction_normalized, primary, pattern.cone_half_angle)
		"line":
			map._build_line_pattern(map._card_pattern_preview, origin, direction_normalized, primary,
				float(pattern.secondary_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL,
				float(pattern.start_offset_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL)

func clear_card_pattern_preview() -> void:
	if map._card_pattern_preview:
		map._card_pattern_preview.visible = false

func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool:
	if pattern == null or pattern.shape == "none":
		return false
	var direction_normalized := direction.normalized() if direction.length() > 0.001 else Vector2(0, 1)
	match pattern.shape:
		"circle":
			return map.is_enemy_in_area_circle(origin, primary)
		"cone":
			return map.is_enemy_in_cone(origin, direction_normalized, primary, pattern.cone_half_angle)
		"line":
			var relative: Vector2 = map.enemy_pos - origin
			var along := relative.dot(direction_normalized)
			var start := float(pattern.start_offset_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL
			var contact_margin: float = map.enemy_area_contact_radius()
			var half_width := float(pattern.secondary_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL * 0.5 + contact_margin
			return along >= start - contact_margin and along <= start + primary + contact_margin \
				and absf(relative.cross(direction_normalized)) <= half_width and map.has_line_of_sight(origin, map.enemy_pos)
	return false

func start_enemy_highlight() -> void:
	map._show_footprint(map._enemy_highlight, map.enemy_pos, map._enemy_shadow_radius)
	map._show_footprint(map._enemy_hover, map.enemy_pos, map._enemy_shadow_radius, map.HOVER_Y)
	map._enemy_hover.visible = false

func clear_enemy_highlight() -> void:
	map._enemy_highlight.visible = false
	map._enemy_hover.visible = false

func start_self_highlight() -> void:
	map._show_footprint(map._self_highlight, map.player_pos, map._player_shadow_radius)
	map._show_footprint(map._self_hover, map.player_pos, map._player_shadow_radius, map.HOVER_Y)
	map._self_hover.visible = false

func clear_self_highlight() -> void:
	map._self_highlight.visible = false
	map._self_hover.visible = false

func is_click_on_enemy(pos: Vector2) -> bool:
	return pos.distance_to(map.enemy_pos) <= map._enemy_shadow_radius + map.CLICK_MARGIN

func is_click_on_player(pos: Vector2) -> bool:
	return pos.distance_to(map.player_pos) <= map._player_shadow_radius + map.CLICK_MARGIN

func update_hover(pos: Vector2) -> void:
	var any_disc: bool = map._move_disc.visible or map._attack_disc.visible \
		or map._trap_system.is_placing() or map._grenade_system.is_active() \
		or map._rock_jump_system.is_active() or map._push_disc.visible \
		or map._push_enemy_disc.visible or map._puddle_system.is_placing()
	var any_target: bool = map._enemy_highlight.visible or map._self_highlight.visible or map._attack_disc.visible
	if not any_disc and not any_target and not map._overwatch_system.selection_active:
		clear_hover()
		return
	if any_disc:
		map._show_single_cell(map._hover_cell, pos)
	else:
		map._hover_cell.visible = false
	map._enemy_hover.visible = (map._enemy_highlight.visible or map._attack_disc.visible) and is_click_on_enemy(pos)
	map._self_hover.visible = map._self_highlight.visible and is_click_on_player(pos)
	map._puddle_system.update_hover_preview(pos)
	map._trap_system.update_hover_preview(pos)
	_update_overwatch_hover(pos)

func clear_hover() -> void:
	map._hover_cell.visible = false
	map._enemy_hover.visible = false
	map._self_hover.visible = false
	map._overwatch_preview_disc.visible = false

func _update_overwatch_hover(pos: Vector2) -> void:
	map._overwatch_system.update_hover(pos)
