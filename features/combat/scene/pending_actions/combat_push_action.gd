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
		host.map_area.start_anchor_selection(host._w(card.primary_range_cells()))
		host.log_requested.emit("Elegí dónde clavar el ancla: el enemigo va a ser arrastrado hacia ahí.")
		return
	host.map_area.start_push_enemy_selection(host._w(card.primary_range_cells()))
	if card.pattern != null:
		host.map_area.show_card_pattern_preview(card.pattern, host.map_area.player_pos, host.map_area.enemy_pos - host.map_area.player_pos, host._w(card.primary_range_cells()))
	host.log_requested.emit("Seleccioná al enemigo para agarrarlo.")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_ANCHOR:
		if host.map_area.movement_distance(host.map_area.player_pos, pos) > host._w(card.primary_range_cells()):
			host.log_requested.emit("Demasiado lejos para clavar el ancla.")
			return
		if not host.map_area.has_line_of_sight(host.map_area.player_pos, pos):
			host.log_requested.emit("Hay algo en el medio: no llegás a clavar el ancla ahí.")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return

	if phase == 0:
		if not host.map_area.is_enemy_in_attack_range(host._w(card.primary_range_cells())):
			host.log_requested.emit("El enemigo está demasiado lejos para agarrarlo.")
			return
		if not host.map_area.is_click_on_enemy(pos):
			return
		if card.card_type == CardActionLine.TYPE_PULL:
			host.pending_cell = host.map_area.player_pos
			host.confirm_popup_show_requested.emit(false)
			return
		phase = 1
		host.map_area.start_push_cone(host._w(card.cast_range_cells()))
		host.log_requested.emit("Elegí hacia dónde empujar al enemigo.")
		return

	if not host.map_area.is_pos_in_push_cone(pos, host._w(card.cast_range_cells())):
		return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(direction_target: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var push_from: Vector2 = host.map_area.enemy_pos

	var landing: Vector2
	match played_card.card_type:
		CardActionLine.TYPE_PULL:
			landing = host.map_area.calculate_drag_landing(host.map_area.player_pos, host._w(played_card.cast_range_cells()))
		CardActionLine.TYPE_ANCHOR:
			landing = host.map_area.calculate_drag_landing(direction_target, host._w(played_card.cast_range_cells()))
		_:
			landing = host.map_area.calculate_push_landing(direction_target, host._w(played_card.cast_range_cells()))
	host.map_area.clear_push_selection()

	# Se gasta antes de las animaciones (ver CombatAttackAction.execute).
	_spend_card()
	host.hand_refresh_requested.emit()

	# 1. Animación de ataque del jugador
	host.map_area.play_player_anim("attack")
	await host.map_area.player_anim_finished
	host.map_area.play_player_anim("idle")

	# 2. El enemigo vuela
	host.map_area.push_enemy_to(landing)
	await host.map_area.enemy_reached_target

	# 3. Animación de daño del enemigo
	host.map_area.play_enemy_anim("damage")
	await host.map_area.enemy_anim_finished
	if host.state.enemy_hp > 0:
		host.map_area.play_enemy_anim("idle")

	var any_zone: bool = await host._apply_enemy_forced_move(played_card.name, push_from, landing)
	if not any_zone:
		match played_card.card_type:
			CardActionLine.TYPE_PULL: host.log_requested.emit("%s: acercaste al enemigo." % played_card.name)
			CardActionLine.TYPE_ANCHOR: host.log_requested.emit("%s: el ancla arrastró al enemigo." % played_card.name)
			_: host.log_requested.emit("%s: empujaste al enemigo." % played_card.name)

	_finish()

func clear() -> void:
	index = -1
	phase = 0
	card = null
	host.map_area.clear_push_selection()
