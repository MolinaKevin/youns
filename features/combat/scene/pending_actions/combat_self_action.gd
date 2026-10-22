class_name CombatSelfAction
extends CombatPendingAction

## block, ward, mp_restore, counter, nova, heal, enchant — cartas que se
## aplican sobre uno mismo. Caso especial entre las familias: ejecuta en el
## mismo click (sobre el propio jugador), sin paso de confirmación.

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	host.map_area.start_self_highlight()
	if card.pattern != null:
		host.map_area.show_card_pattern_preview(card.pattern, host.map_area.player_pos, Vector2(0, 1), host._w(card.primary_range_cells()))

func on_tile_selected(pos: Vector2) -> void:
	if host.map_area.is_click_on_player(pos):
		execute(pos)

func execute(_cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	if played_card.card_type == CardActionLine.TYPE_HEAL:
		var healed: int = host.state.heal_player(played_card.restore_amount)
		host.log_requested.emit("%s: te curás %d (%d/%d)." % [played_card.name, healed, host.state.player_hp, host.state.player_max_hp])
	elif played_card.card_type == CardActionLine.TYPE_ENCHANT:
		host.state.player_enchant_damage = played_card.damage
		host.state.player_enchant_status = "" if played_card.status_effect == "ninguno" else played_card.status_effect
		host.log_requested.emit("%s: tu próximo ataque físico es mágico y suma %d de daño." % [played_card.name, played_card.damage])
	elif played_card.card_type == CardActionLine.TYPE_NOVA:
		host._execute_nova.call_deferred(played_card)
	elif played_card.card_type == CardActionLine.TYPE_COUNTER:
		host.state.player_counter_damage += played_card.damage
		host.log_requested.emit("%s: contraataque listo, %d de daño a quien te pegue cuerpo a cuerpo." % [played_card.name, host.state.player_counter_damage])
	elif played_card.card_type == CardActionLine.TYPE_MP_RESTORE:
		var gained: int = host.state.restore_mp(played_card.restore_amount)
		host.log_requested.emit("%s: recuperás %d MP (%d/%d)." % [played_card.name, gained, host.state.player_mp, host.state.player_max_mp])
	elif played_card.card_type == CardActionLine.TYPE_WARD:
		host.state.player_ward += played_card.block_amount
		host.log_requested.emit("%s: escudo mágico %d." % [played_card.name, host.state.player_ward])
	else:
		host.state.player_block += played_card.block_amount
		host.log_requested.emit("%s: bloqueo %d." % [played_card.name, host.state.player_block])
	_spend_card()
	host.hand_refresh_requested.emit()
	host.ui_update_requested.emit()

func clear() -> void:
	index = -1
	card = null
	host.map_area.clear_self_highlight()
	host.map_area.clear_card_pattern_preview()
