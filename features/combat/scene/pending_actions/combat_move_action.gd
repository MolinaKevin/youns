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

func is_active() -> bool:
	return index >= 0 or started

func configure(p_index: int, p_range_cells: int) -> void:
	index = p_index
	range_cells = p_range_cells
	host.board.selection.targeting.modes.start_move_selection(host.w(p_range_cells))

func on_tile_selected(pos: Vector2) -> void:
	# Cada rechazo avisa en el log: antes el clic no hacía nada sin explicación.
	var plan_result := host.board.movement.plan_player_move(pos)
	match plan_result:
		"range":
			host.emit_log("combat.log.move.out_of_range", [range_cells])
			return
		"blocked":
			host.emit_log("combat.log.move.blocked")
			return
		"no_path":
			host.emit_log("combat.log.move.no_path")
			return
	host.pending_cell = host.board.movement.planned_destination()
	host.board.presentation.targeting.overlay.path.show_path_preview()
	host.confirm_popup_show_requested.emit(started)

func execute(cell: Vector2) -> void:
	if index < 0 and not started:
		return

	var move_from: Vector2 = host.board.state.player_position()
	var dist_moved: float = host.board.movement.path_cost()
	var moved: bool = host.board.movement.try_move_player_to(cell)
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
		host.emit_log("combat.log.move.played", [played_card.name])
		host.state.turn_actions.remove_at(index)
		index = -1
		started = true

	var remaining := maxi(0, range_cells - roundi(dist_moved / CombatGrid.CELL))
	if remaining >= MIN_REMAINING_CELLS_TO_CONTINUE:
		host.emit_log("combat.log.move.remaining_range", [remaining])
		range_cells = remaining
		host.board.selection.targeting.modes.start_move_selection(host.w(remaining))
		host.end_move_button_visible_changed.emit(true)
		host.hand_refresh_requested.emit()
		host.ui_update_requested.emit()
	else:
		host.end_move_button_visible_changed.emit(false)
		clear()
		# hand_refresh_requested es síncrona: el flujo de turnos consulta si hay
		# una selección pendiente durante esa señal. Hay que soltar la acción
		# antes del refresco para que pueda avanzar la línea automáticamente.
		if host.current_action() == self:
			host.clear_current_action()
		if host.move_mode:
			host.move_mode_button_reset_requested.emit()
		host.hand_refresh_requested.emit()
		host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	range_cells = 0
	started = false
	card = null
	host.end_move_button_visible_changed.emit(false)
	host.board.presentation.targeting.overlay.path.clear_path_preview()
	host.board.selection.targeting.modes.clear_move_selection()
