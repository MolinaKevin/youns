class_name CombatTrapAction
extends CombatPendingAction

## trap_place (cerca, rango fijo) y trap_throw (a distancia, con cast_range).

func start(p_index: int, p_card: CardActionLine, nearby: bool) -> void:
	index = p_index
	card = p_card
	if nearby:
		host.map_area.start_trap_placement(host._w(CardActionLine.cells_for_modules(CombatPlayerActions.NEARBY_TRAP_MODULES)), host._w(card.primary_range_cells()))
		host.log_requested.emit("Colocá %s cerca (rango %d módulos)." % [card.name, CombatPlayerActions.NEARBY_TRAP_MODULES])
	else:
		host.map_area.start_trap_placement(host._w(card.cast_range_cells()), host._w(card.primary_range_cells()))
		host.log_requested.emit("Tirá %s — elegí una casilla hasta %s módulos." % [card.name, card.cast_module_label()])

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var is_nearby := played_card.card_type == CardActionLine.TYPE_TRAP_PLACE

	if is_nearby and host.map_area.movement_distance(host.map_area.player_pos, cell) > host._w(CardActionLine.cells_for_modules(CombatPlayerActions.NEARBY_TRAP_MODULES)):
		host.log_requested.emit("Demasiado lejos para colocar %s." % played_card.name)
		return

	if not is_nearby and played_card.cast_range_cells() > 0 and host.map_area.movement_distance(host.map_area.player_pos, cell) > host._w(played_card.cast_range_cells()):
		host.log_requested.emit("Demasiado lejos para tirar %s." % played_card.name)
		return

	if not host.map_area.has_line_of_sight(host.map_area.player_pos, cell):
		host.log_requested.emit("Hay algo en el medio: no podés colocar %s ahí." % played_card.name)
		return
	host.map_area.place_trap(cell, host._w(played_card.primary_range_cells()), played_card.damage, played_card.name)
	host.log_requested.emit("%s: colocada en (%.1f,%.1f)." % [played_card.name, cell.x, cell.y])
	_spend_card()
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.map_area.clear_trap_placement()
