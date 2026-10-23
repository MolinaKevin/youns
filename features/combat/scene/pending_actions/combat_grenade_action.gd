class_name CombatGrenadeAction
extends CombatPendingAction

## Carta "grenade": rebota hacia el punto elegido y explota ahí.

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	# El alcance grande se muestra como un círculo simple: calcular visibilidad
	# para cada celda congelaba el combate. La línea de visión se valida al elegir.
	host.map_area.start_trap_placement(host._w(card.cast_range_cells()), 1.0, false)
	host.log_requested.emit("%s seleccionada. Elegí una casilla hasta %s módulos (rebote: %.1f)." % [card.name, card.cast_module_label(), card.bounce])

func on_tile_selected(pos: Vector2) -> void:
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(target: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]

	if played_card.cast_range_cells() > 0 and host.map_area.movement_distance(host.map_area.player_pos, target) > host._w(played_card.cast_range_cells()):
		host.log_requested.emit("Demasiado lejos para tirar %s." % played_card.name)
		return

	if not host.map_area.has_line_of_sight(host.map_area.player_pos, target):
		host.log_requested.emit("Hay algo en el medio: no podés tirar %s ahí." % played_card.name)
		return

	host.map_area.clear_trap_placement()
	var landing: Vector2 = host.map_area.calculate_grenade_landing(host.map_area.player_pos, target, played_card.bounce)
	var radius := host._w(played_card.primary_range_cells())
	if played_card.pattern != null:
		host.map_area.show_card_pattern_preview(played_card.pattern, landing, Vector2(0, 1), radius)
	else:
		host.map_area.show_grenade_preview(landing, radius)
	# Se gasta antes de las animaciones (ver CombatAttackAction.execute).
	host.state.turn_actions.remove_at(index)
	index = -1
	card = null
	host.hand_refresh_requested.emit()
	var hit_enemy: bool = host.map_area.is_enemy_in_card_pattern(played_card.pattern, landing, Vector2(0, 1), radius) if played_card.pattern != null else host.map_area.is_enemy_in_explosion(landing, radius)
	if hit_enemy:
		host.log_requested.emit("¡%s cae en (%.1f,%.1f) — %d de daño!" % [played_card.name, landing.x, landing.y, played_card.damage])
		await host._deal_damage_to_enemy.call(played_card.damage, false, played_card.damage_type)
	else:
		host.log_requested.emit("%s cae en (%.1f,%.1f) — falló." % [played_card.name, landing.x, landing.y])

	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	host.card_preview_hide_requested.emit()
	host.map_area.clear_grenade_preview()
	host.map_area.clear_card_pattern_preview()
	_finish()

func clear() -> void:
	index = -1
	card = null
	host.map_area.clear_grenade_preview()
	host.map_area.clear_trap_placement()
