class_name CombatPushAction
extends CombatPendingAction

## push, pull y anchor comparten la selección: el tipo de carta decide adónde
## va el enemigo. anchor es de una sola fase (elegir dónde clavarla); push es
## de dos (elegir al enemigo, después la dirección); pull se resuelve apenas
## se elige al enemigo, sin fase 2.

var phase: int = 0

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	phase = 0
	card = p_card
	if card.card_type == CardActionLine.TYPE_ANCHOR:
		host.board.push.selection.start_anchor_selection(host.w(card.primary_range_cells()), host.board.state.player_position())
		host.emit_log("combat.log.push.select_anchor")
		return
	host.board.push.selection.start_push_enemy_selection(host.w(card.primary_range_cells()))
	if card.pattern != null:
		host.board.presentation.patterns.show_card_pattern(card.pattern, host.board.state.player_position(), host.board.state.enemy_position() - host.board.state.player_position(), host.w(card.primary_range_cells()))
	host.emit_log("combat.log.push.select_enemy")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_ANCHOR:
		if host.board.queries.actors.movement_distance(host.board.state.player_position(), pos) > host.w(card.primary_range_cells()):
			host.emit_log("combat.log.push.anchor_too_far")
			return
		if not host.board.queries.line_of_sight.has_line_of_sight(host.board.state.player_position(), pos):
			host.emit_log("combat.log.push.anchor_blocked")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return

	if phase == 0:
		if not host.board.queries.actors.is_enemy_in_attack_range(host.w(card.primary_range_cells())):
			host.emit_log("combat.log.push.enemy_too_far")
			return
		if not host.board.selection.targeting.queries.is_click_on_enemy(pos):
			return
		if card.card_type == CardActionLine.TYPE_PULL:
			host.pending_cell = host.board.state.player_position()
			host.confirm_popup_show_requested.emit(false)
			return
		phase = 1
		host.board.push.selection.start_push_cone(host.w(card.cast_range_cells()))
		host.emit_log("combat.log.push.select_direction")
		return

	if not host.board.push.queries.is_pos_in_push_cone(pos, host.w(card.cast_range_cells())):
		return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(direction_target: Vector2) -> void:
	var flow := _flow()
	if not _flow_is_active(flow):
		return
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var push_from: Vector2 = host.board.state.enemy_position()

	var landing: Vector2
	match played_card.card_type:
		CardActionLine.TYPE_PULL:
			landing = host.board.push.queries.calculate_drag_landing(host.board.state.player_position(), host.w(played_card.cast_range_cells()))
		CardActionLine.TYPE_ANCHOR:
			landing = host.board.push.queries.calculate_drag_landing(direction_target, host.w(played_card.cast_range_cells()))
		_:
			landing = host.board.push.queries.calculate_push_landing(direction_target, host.w(played_card.cast_range_cells()))
	host.board.push.clear_push_selection()

	# Se gasta antes de las animaciones (ver CombatAttackAction.execute).
	_spend_card()
	host.hand_refresh_requested.emit()

	# 1. Animación de ataque del jugador
	host.board.actors.presentation.play_player_animation("attack")
	await host.board.player_anim_finished
	if not _flow_is_active(flow):
		return
	host.board.actors.presentation.play_player_animation("idle")

	# 2. El enemigo vuela
	host.board.push.execution.push_enemy_to(landing)
	await host.board.enemy_reached_target
	if not _flow_is_active(flow):
		return

	# 3. Animación de daño del enemigo
	host.board.actors.presentation.play_enemy_animation("damage")
	await host.board.enemy_anim_finished
	if not _flow_is_active(flow):
		return
	if host.state.enemy_hp > 0:
		host.board.actors.presentation.play_enemy_animation("idle")

	var any_zone: bool = await host._apply_enemy_forced_move(played_card.name, push_from, landing, flow)
	if not _flow_is_active(flow):
		return
	if not any_zone:
		match played_card.card_type:
			CardActionLine.TYPE_PULL: host.emit_log("combat.log.push.pulled", [played_card.name])
			CardActionLine.TYPE_ANCHOR: host.emit_log("combat.log.push.anchored", [played_card.name])
			_: host.emit_log("combat.log.push.pushed", [played_card.name])

	_finish()

func clear() -> void:
	index = -1
	phase = 0
	card = null
	host.board.push.clear_push_selection()
