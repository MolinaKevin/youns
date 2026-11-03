class_name CombatTrapAction
extends CombatPendingAction

## trap_place (cerca, rango fijo) y trap_throw (a distancia, con cast_range).

func start(p_index: int, p_card: CardActionLine, nearby: bool) -> void:
	index = p_index
	card = p_card
	if nearby:
		host.board.placement.traps.start_trap_placement(host.w(CardActionLine.cells_for_modules(CombatPlayerActions.NEARBY_TRAP_MODULES)), host.w(card.primary_range_cells()))
		host.emit_log("combat.log.trap.select_nearby", [card.name, CombatPlayerActions.NEARBY_TRAP_MODULES])
	else:
		host.board.placement.traps.start_trap_placement(host.w(card.cast_range_cells()), host.w(card.primary_range_cells()))
		host.emit_log("combat.log.trap.select_throw", [card.name, card.cast_module_label()])

func on_tile_selected(pos: Vector2) -> void:
	_request_confirm(pos)

func execute(cell: Vector2) -> void:
	if not _require_valid_index():
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var is_nearby := played_card.card_type == CardActionLine.TYPE_TRAP_PLACE

	if is_nearby and host.board.queries.actors.movement_distance(host.board.state.player_position(), cell) > host.w(CardActionLine.cells_for_modules(CombatPlayerActions.NEARBY_TRAP_MODULES)):
		host.emit_log("combat.log.trap.nearby_too_far", [played_card.name])
		return

	if not is_nearby and played_card.cast_range_cells() > 0 and host.board.queries.actors.movement_distance(host.board.state.player_position(), cell) > host.w(played_card.cast_range_cells()):
		host.emit_log("combat.log.trap.throw_too_far", [played_card.name])
		return

	if not host.board.queries.line_of_sight.has_line_of_sight(host.board.state.player_position(), cell):
		host.emit_log("combat.log.trap.blocked", [played_card.name])
		return
	host.board.placement.traps.place_trap(cell, host.w(played_card.primary_range_cells()), played_card.damage, played_card.name)
	host.emit_log("combat.log.trap.placed", [played_card.name, cell.x, cell.y])
	_spend_card()
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.board.placement.traps.clear_trap_placement()
