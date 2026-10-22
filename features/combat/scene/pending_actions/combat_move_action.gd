class_name CombatMoveAction
extends CombatPendingAction

## Carta "move" (desde la mano o desde el modo mover). A diferencia de las
## demás familias, tiene reingreso: cada click gasta parte del rango y, si
## queda rango, vuelve a pedir destino en vez de terminar. `host.play_as_move`
## y `host.start_move_selection` son las dos entradas (validan enredado /
## congelado / penalización y llaman `configure`); acá sólo vive la selección
## en el mapa y la ejecución paso a paso.

var range_cells: int = 0
var started: bool = false

func is_active() -> bool:
	return index >= 0 or started

func configure(p_index: int, p_range_cells: int) -> void:
	index = p_index
	range_cells = p_range_cells
	host.map_area.start_move_selection(host._w(p_range_cells))

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	# Cada rechazo avisa en el log: antes el clic no hacía nada sin explicación.
	match host.map_area.plan_player_move(pos):
		"range":
			host.log_requested.emit("Ese lugar está fuera de tu alcance de movimiento (%d)." % range_cells)
			return
		"blocked":
			host.log_requested.emit("No entrás en ese lugar: hay un obstáculo o el enemigo.")
			return
		"no_path":
			host.log_requested.emit("No hay camino hasta ahí dentro de tu alcance.")
			return
	host.map_area.show_path_preview()
	host.confirm_popup_show_requested.emit(started)

func execute(cell: Vector2) -> void:
	if index < 0 and not started:
		return
	if not host.map_area.has_method("try_move_player_to"):
		return

	var move_from: Vector2 = host.map_area.player_pos
	var dist_moved: float = host.map_area.get_path_cost()
	var moved: bool = host.map_area.try_move_player_to(cell)
	if not moved:
		host.log_requested.emit("Movimiento inválido.")
		return

	host.apply_player_zone_effects(move_from, host.map_area.player_pos)

	var trap_dmg: int = host.map_area.check_and_trigger_traps_along_path(move_from, host.map_area.player_pos, host.map_area.player_area_contact_radius())
	if trap_dmg > 0:
		host._deal_damage_to_player.call(trap_dmg)
		host.log_requested.emit("Pisaste una trampa en el camino! %d daño." % trap_dmg)
		if host._check_combat_end.call():
			return

	if not started:
		var played_card: CardActionLine = host.state.turn_actions[index]
		host.log_requested.emit("%s: jugada." % played_card.name)
		host.state.turn_actions.remove_at(index)
		index = -1
		started = true

	var remaining := maxi(0, range_cells - roundi(dist_moved / CombatGrid.CELL))
	if remaining > 0:
		host.log_requested.emit("Rango restante: %d" % remaining)
		range_cells = remaining
		host.map_area.start_move_selection(host._w(remaining))
		host.end_move_button_visible_changed.emit(true)
		host.hand_refresh_requested.emit()
		host.ui_update_requested.emit()
	else:
		host.end_move_button_visible_changed.emit(false)
		clear()
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
	host.map_area.clear_path_preview()
	if host.map_area.has_method("clear_move_selection"):
		host.map_area.clear_move_selection()
