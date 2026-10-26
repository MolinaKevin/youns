class_name CombatTargeting
extends RefCounted

## Modos de selección y sus previsualizaciones. Usa a MapArea como fachada de
## terreno, navegación y overlay, sin ser dueño de esas reglas.
var map: MapArea
var selected_move_range := 0.0
var selected_attack_range := 0.0

func start_move_selection(move_range: float) -> void:
	selected_move_range = move_range
	var visible_cells: Array[Vector2i] = map.terrain.reachable_cells(map.player_pos, move_range, map.player_elevation,
		map.actors.player_radius(), map.enemy_pos, map.actors.enemy_radius())
	map.presentation.show_move_selection(visible_cells)

func clear_move_selection() -> void:
	selected_move_range = 0.0
	map.presentation.clear_move_selection()

func show_move_preview(pos: Vector2) -> void:
	map.presentation.show_move_preview(pos)

func clear_move_preview() -> void:
	map.presentation.clear_move_preview()

func show_path_preview() -> void:
	map.presentation.show_path_preview()

func clear_path_preview() -> void:
	map.presentation.clear_path_preview()

func start_attack_selection(attack_range: float) -> void:
	selected_attack_range = attack_range
	map.presentation.show_attack_selection(attack_range)

func clear_attack_selection() -> void:
	selected_attack_range = 0.0
	map.presentation.clear_attack_selection()
	clear_card_pattern_preview()

func show_card_pattern_preview(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> void:
	map.presentation.show_card_pattern(pattern, origin, direction, primary)

func clear_card_pattern_preview() -> void:
	map.presentation.clear_card_pattern()

func is_enemy_in_card_pattern(pattern: CardPattern, origin: Vector2, direction: Vector2, primary: float) -> bool:
	if pattern == null or pattern.shape == "none":
		return false
	var direction_normalized := direction.normalized() if direction.length() > 0.001 else Vector2(0, 1)
	match pattern.shape:
		"circle":
			return map.queries.is_enemy_in_area_circle(origin, primary)
		"cone":
			return map.queries.is_enemy_in_cone(origin, direction_normalized, primary, pattern.cone_half_angle)
		"line":
			var relative: Vector2 = map.enemy_pos - origin
			var along := relative.dot(direction_normalized)
			var start := float(pattern.start_offset_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL
			var contact_margin: float = map.terrain.enemy_contact_radius()
			var half_width := float(pattern.secondary_modules * CardActionLine.MOVEMENT_MODULE_CELLS) * CombatGrid.CELL * 0.5 + contact_margin
			return along >= start - contact_margin and along <= start + primary + contact_margin \
				and absf(relative.cross(direction_normalized)) <= half_width and map.terrain.has_line_of_sight(origin, map.enemy_pos)
	return false

func start_enemy_highlight() -> void:
	map.presentation.show_enemy_highlight()

func clear_enemy_highlight() -> void:
	map.presentation.clear_enemy_highlight()

func start_self_highlight() -> void:
	map.presentation.show_self_highlight()

func clear_self_highlight() -> void:
	map.presentation.clear_self_highlight()

func is_click_on_enemy(pos: Vector2) -> bool:
	return pos.distance_to(map.enemy_pos) <= map.actors.enemy_radius() + map.CLICK_MARGIN

func is_click_on_player(pos: Vector2) -> bool:
	return pos.distance_to(map.player_pos) <= map.actors.player_radius() + map.CLICK_MARGIN

func update_hover(pos: Vector2) -> void:
	var has_placement: bool = map.interactions.has_active_placement()
	if not has_placement and not map.presentation.has_active_targeting_overlay():
		clear_hover()
		return
	map.presentation.update_targeting_hover(pos,
		map.presentation.has_enemy_targeting_overlay() and is_click_on_enemy(pos),
		map.presentation.has_self_targeting_overlay() and is_click_on_player(pos),
		has_placement or map.presentation.has_active_targeting_overlay())
	map.interactions.update_hover_previews(pos)

func clear_hover() -> void:
	map.presentation.clear_targeting_hover()
