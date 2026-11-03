class_name CombatPuddleAction
extends CombatPendingAction

## Carta "puddle": elegir un punto del mapa y dejar un charco.

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	host.board.placement.puddles.start_puddle_placement(host.w(card.cast_range_cells()), card.puddle_effect, host.w(card.primary_range_cells()))
	host.emit_log("combat.log.puddle.select", [card.cast_module_label()])

func on_tile_selected(pos: Vector2) -> void:
	_request_confirm(pos)

func execute(cell: Vector2) -> void:
	if not _require_valid_index():
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	host.board.placement.puddles.clear_puddle_placement()
	host.board.placement.puddles.place_puddle(cell, host.w(played_card.primary_range_cells()), played_card.puddle_effect, played_card.duration, played_card.damage)
	_spend_card()
	host.emit_log("combat.log.puddle.placed", [played_card.name])
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.board.placement.puddles.clear_puddle_placement()
