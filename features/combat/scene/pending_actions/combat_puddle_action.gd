class_name CombatPuddleAction
extends CombatPendingAction

## Carta "puddle": elegir un punto del mapa y dejar un charco.

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	host.map_area.interactions.start_puddle_placement(host.w(card.cast_range_cells()), card.puddle_effect, host.w(card.primary_range_cells()))
	host.emit_log("combat.log.puddle.select", [card.cast_module_label()])

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	host.map_area.interactions.clear_puddle_placement()
	host.map_area.interactions.place_puddle(cell, host.w(played_card.primary_range_cells()), played_card.puddle_effect, played_card.duration, played_card.damage)
	_spend_card()
	host.emit_log("combat.log.puddle.placed", [played_card.name])
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.map_area.interactions.clear_puddle_placement()
