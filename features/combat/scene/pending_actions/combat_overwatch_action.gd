class_name CombatOverwatchAction
extends CombatPendingAction

## Carta "overwatch": apuntar un cono y dejarlo armado para el resto de la
## ronda. Único caso donde execute() usa una dirección guardada (`dir`) en vez
## del punto clickeado — los tests que no pasan por on_tile_selected fijan
## `dir` directamente antes de llamar a execute().

var dir: Vector2 = Vector2.ZERO

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	var half_angle := card.pattern.cone_half_angle if card.pattern != null else 10.0
	host.map_area.interactions.start_overwatch_selection(host.w(card.primary_range_cells()), half_angle)
	host.emit_log("combat.log.overwatch.select_direction")

func on_tile_selected(pos: Vector2) -> void:
	var new_dir: Vector2 = pos - host.map_area.player_pos
	if new_dir.length() > 0.2:
		dir = new_dir.normalized()
		host.confirm_popup_show_requested.emit(false)

func execute(_cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	host.map_area.interactions.clear_overwatch_selection()
	var half_angle := played_card.pattern.cone_half_angle if played_card.pattern != null else 10.0
	host.map_area.interactions.place_overwatch(host.map_area.player_pos, dir, host.w(played_card.primary_range_cells()), half_angle)
	host.state.player_overwatch_active = true
	host.state.player_overwatch_origin = host.map_area.player_pos
	host.state.player_overwatch_dir = dir
	host.state.player_overwatch_range = host.w(played_card.primary_range_cells())
	host.state.player_overwatch_half_angle = half_angle
	host.state.player_overwatch_damage = played_card.damage
	host.state.player_overwatch_damage_type = played_card.damage_type
	_spend_card()
	host.emit_log("combat.log.overwatch.active", [played_card.name])
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	dir = Vector2.ZERO
	host.map_area.interactions.clear_overwatch_selection()
