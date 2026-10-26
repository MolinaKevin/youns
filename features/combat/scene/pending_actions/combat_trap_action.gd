class_name CombatTrapAction
extends CombatPendingAction

## trap_place (cerca, rango fijo) y trap_throw (a distancia, con cast_range).

func start(p_index: int, p_card: CardActionLine, nearby: bool) -> void:
	index = p_index
	card = p_card
	if nearby:
		host.map_area.interactions.start_trap_placement(host.w(CardActionLine.cells_for_modules(CombatPlayerActions.NEARBY_TRAP_MODULES)), host.w(card.primary_range_cells()))
		host.emit_log("combat.log.trap.select_nearby", [card.name, CombatPlayerActions.NEARBY_TRAP_MODULES])
	else:
		host.map_area.interactions.start_trap_placement(host.w(card.cast_range_cells()), host.w(card.primary_range_cells()))
		host.emit_log("combat.log.trap.select_throw", [card.name, card.cast_module_label()])

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var is_nearby := played_card.card_type == CardActionLine.TYPE_TRAP_PLACE

	if is_nearby and host.map_area.queries.movement_distance(host.map_area.player_pos, cell) > host.w(CardActionLine.cells_for_modules(CombatPlayerActions.NEARBY_TRAP_MODULES)):
		host.emit_log("combat.log.trap.nearby_too_far", [played_card.name])
		return

	if not is_nearby and played_card.cast_range_cells() > 0 and host.map_area.queries.movement_distance(host.map_area.player_pos, cell) > host.w(played_card.cast_range_cells()):
		host.emit_log("combat.log.trap.throw_too_far", [played_card.name])
		return

	if not host.map_area.queries.has_line_of_sight(host.map_area.player_pos, cell):
		host.emit_log("combat.log.trap.blocked", [played_card.name])
		return
	host.map_area.interactions.place_trap(cell, host.w(played_card.primary_range_cells()), played_card.damage, played_card.name)
	host.emit_log("combat.log.trap.placed", [played_card.name, cell.x, cell.y])
	_spend_card()
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.map_area.interactions.clear_trap_placement()
