class_name CombatGrenadeAction
extends CombatPendingAction

## Carta "grenade": rebota hacia el punto elegido y explota ahí.

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	# El alcance grande se muestra como un círculo simple: calcular visibilidad
	# para cada celda congelaba el combate. La línea de visión se valida al elegir.
	host.board.placement.traps.start_trap_placement(host.w(card.cast_range_cells()), 1.0, false)
	host.emit_log("combat.log.grenade.select", [card.name, card.cast_module_label(), card.bounce])

func on_tile_selected(pos: Vector2) -> void:
	_request_confirm(pos)

func execute(target: Vector2) -> void:
	var flow := _flow()
	if _should_abort_execute(flow):
		return
	var played_card: CardActionLine = host.state.turn_actions[index]

	if played_card.cast_range_cells() > 0 and host.board.queries.actors.movement_distance(host.board.state.player_position(), target) > host.w(played_card.cast_range_cells()):
		host.emit_log("combat.log.grenade.too_far", [played_card.name])
		return

	if not host.board.queries.line_of_sight.has_line_of_sight(host.board.state.player_position(), target):
		host.emit_log("combat.log.grenade.blocked", [played_card.name])
		return

	host.board.placement.traps.clear_trap_placement()
	var landing: Vector2 = host.board.placement.grenades.grenade_landing(host.board.state.player_position(), target, played_card.bounce)
	var radius := host.w(played_card.primary_range_cells())
	if played_card.pattern != null:
		host.board.presentation.patterns.show_card_pattern(played_card.pattern, landing, Vector2(0, 1), radius)
	else:
		host.board.placement.grenades.show_grenade_preview(landing, radius)
	# Se gasta antes de las animaciones (ver CombatAttackAction.execute).
	host.state.turn_actions.remove_at(index)
	index = -1
	card = null
	host.hand_refresh_requested.emit()
	var hit_enemy: bool = host.board.selection.targeting.queries.is_enemy_in_card_pattern(played_card.pattern, landing, Vector2(0, 1), radius) if played_card.pattern != null else host.board.placement.grenades.is_enemy_in_explosion(landing, radius)
	if hit_enemy:
		host.emit_log("combat.log.grenade.hits_enemy", [played_card.name, landing.x, landing.y, played_card.damage])
		await host.deal_damage_to_enemy.call(played_card.damage, false, played_card.damage_type)
		if not _flow_is_active(flow):
			return
	else:
		host.emit_log("combat.log.grenade.missed", [played_card.name, landing.x, landing.y])

	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	if not _flow_is_active(flow):
		return
	host.card_preview_hide_requested.emit()
	host.board.placement.grenades.clear_grenade_preview()
	host.board.presentation.patterns.clear_card_pattern()
	_finish()

func clear() -> void:
	index = -1
	card = null
	host.board.placement.grenades.clear_grenade_preview()
	host.board.placement.traps.clear_trap_placement()
