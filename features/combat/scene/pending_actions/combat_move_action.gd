class_name CombatMoveAction
extends CombatPendingAction

## Carta "move" (desde la mano o desde el modo mover). A diferencia de las
## demás familias, tiene reingreso: cada click gasta parte del rango y, si
## queda rango, vuelve a pedir destino en vez de terminar. Las entradas de
## movimiento de CombatPlayerActions validan enredado/congelado/penalización
## y llaman `configure`; acá sólo vive la selección mediante `board.selection`
## y la ejecución paso a paso.

var range_cells: int = 0
var started: bool = false

# Una o dos casillas de navegación (8–16 cm) pueden quedar por el ajuste entre
# la grilla y el borde circular, pero no alcanzan para un desplazamiento útil.
const MIN_REMAINING_CELLS_TO_CONTINUE := 3
const TRACE_PREFIX := "[CombatMoveTrace]"

func _trace(event: String, details: String = "") -> void:
	var current_is_self: bool = host != null and host.current_action() == self
	print("%s action.%s | index=%d started=%s active=%s current_is_move=%s range_cells=%d%s" % [
		TRACE_PREFIX, event, index, started, is_active(), current_is_self, range_cells,
		(" | " + details) if not details.is_empty() else "",
	])

func is_active() -> bool:
	return index >= 0 or started

func configure(p_index: int, p_range_cells: int) -> void:
	index = p_index
	range_cells = p_range_cells
	_trace("configure", "requested_index=%d requested_range=%d world_range=%.3f" % [p_index, p_range_cells, host.w(p_range_cells)])
	host.board.selection.targeting.modes.start_move_selection(host.w(p_range_cells))

func on_tile_selected(pos: Vector2) -> void:
	_trace("tile_selected", "clicked=%s" % pos)
	# Cada rechazo avisa en el log: antes el clic no hacía nada sin explicación.
	var plan_result := host.board.movement.plan_player_move(pos)
	_trace("plan_result", "result='%s' destination=%s path_cost=%.3f" % [plan_result, host.board.movement.planned_destination(), host.board.movement.path_cost()])
	match plan_result:
		"range":
			_trace("selection_rejected", "reason=range")
			host.emit_log("combat.log.move.out_of_range", [range_cells])
			return
		"blocked":
			_trace("selection_rejected", "reason=blocked")
			host.emit_log("combat.log.move.blocked")
			return
		"no_path":
			_trace("selection_rejected", "reason=no_path")
			host.emit_log("combat.log.move.no_path")
			return
	host.pending_cell = host.board.movement.planned_destination()
	_trace("confirmation_requested", "pending_cell=%s" % host.pending_cell)
	host.board.presentation.targeting.overlay.path.show_path_preview()
	host.confirm_popup_show_requested.emit(started)

func execute(cell: Vector2) -> void:
	_trace("execute_enter", "cell=%s" % cell)
	if index < 0 and not started:
		_trace("execute_ignored", "reason=no_active_move")
		return

	var move_from: Vector2 = host.board.state.player_position()
	var dist_moved: float = host.board.movement.path_cost()
	_trace("move_attempt", "from=%s to=%s path_cost=%.3f path_cells=%.3f" % [move_from, cell, dist_moved, dist_moved / CombatGrid.CELL])
	var moved: bool = host.board.movement.try_move_player_to(cell)
	_trace("move_result", "moved=%s logical_position=%s" % [moved, host.board.state.player_position()])
	if not moved:
		host.emit_log("combat.log.move.invalid")
		return

	host.apply_player_zone_effects(move_from, host.board.state.player_position())

	var trap_dmg: int = host.board.effects.traps.trigger_traps_along(move_from, host.board.state.player_position(), host.board.queries.actors.player_area_contact_radius())
	if trap_dmg > 0:
		host.deal_damage_to_player.call(trap_dmg)
		host.emit_log("combat.log.move.trap_triggered", [trap_dmg])
		if host.check_combat_end.call():
			return

	if not started:
		var played_card: CardActionLine = host.state.turn_actions[index]
		_trace("consume_card", "card='%s' turn_actions_before=%d" % [played_card.name, host.state.turn_actions.size()])
		host.emit_log("combat.log.move.played", [played_card.name])
		host.state.turn_actions.remove_at(index)
		index = -1
		started = true
		_trace("card_consumed", "turn_actions_after=%d" % host.state.turn_actions.size())

	var remaining := maxi(0, range_cells - roundi(dist_moved / CombatGrid.CELL))
	_trace("remaining_calculated", "distance=%.3f spent_cells=%d remaining=%d threshold=%d" % [dist_moved, roundi(dist_moved / CombatGrid.CELL), remaining, MIN_REMAINING_CELLS_TO_CONTINUE])
	if remaining >= MIN_REMAINING_CELLS_TO_CONTINUE:
		_trace("continue_selection", "remaining=%d" % remaining)
		host.emit_log("combat.log.move.remaining_range", [remaining])
		range_cells = remaining
		host.board.selection.targeting.modes.start_move_selection(host.w(remaining))
		host.end_move_button_visible_changed.emit(true)
		host.hand_refresh_requested.emit()
		host.ui_update_requested.emit()
	else:
		_trace("finish_threshold_reached", "remaining=%d" % remaining)
		host.end_move_button_visible_changed.emit(false)
		clear()
		# hand_refresh_requested es síncrona: el flujo de turnos consulta si hay
		# una selección pendiente durante esa señal. Hay que soltar la acción
		# antes del refresco para que pueda avanzar la línea automáticamente.
		if host.current_action() == self:
			host.clear_current_action()
			_trace("current_action_released_before_refresh")
		if host.move_mode:
			host.move_mode_button_reset_requested.emit()
		_trace("before_hand_refresh")
		host.hand_refresh_requested.emit()
		_trace("after_hand_refresh")
		host.ui_update_requested.emit()
		_trace("execute_exit_finished")

func clear() -> void:
	_trace("clear_enter")
	index = -1
	range_cells = 0
	started = false
	card = null
	host.end_move_button_visible_changed.emit(false)
	host.board.presentation.targeting.overlay.path.clear_path_preview()
	host.board.selection.targeting.modes.clear_move_selection()
	_trace("clear_exit")
