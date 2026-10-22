class_name CombatPuddleAction
extends CombatPendingAction

## Carta "puddle": elegir un punto del mapa y dejar un charco.

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	host.map_area.start_puddle_placement(host._w(card.cast_range_cells()), card.puddle_effect, host._w(card.primary_range_cells()))
	host.log_requested.emit("Elegí dónde lanzar el charco (rango %s módulos)." % card.cast_module_label())

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	host.map_area.clear_puddle_placement()
	host.map_area.place_puddle(cell, host._w(played_card.primary_range_cells()), played_card.puddle_effect, played_card.duration, played_card.damage)
	_spend_card()
	host.log_requested.emit("%s: colocado." % played_card.name)
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.map_area.clear_puddle_placement()
