class_name CombatTurnFlow
extends RefCounted

## El loop de turnos: planificación (elegir 2 cartas), revelado, actuar
## línea por línea, fin de ronda y los eventos que pasan al cerrarla (árboles,
## zonas demoradas, charcos/estados). `host` es el Combat dueño exclusivo de
## esta instancia — coordina `turn` (CombatTurnController), `player_actions`,
## `enemy_ai` y los widgets de mano/plan/orden, pero el "qué pasa" de cada
## paso vive en esos otros objetos.

var host: Combat

func _init(p_host: Combat) -> void:
	host = p_host

# ── Gestión de mazos ─────────────────────────────────────────────────────────

func setup_draw_pile() -> void:
	# El mazo propio de la partida (con lo que le cambiaron las evoluciones).
	var deck_cards := DeckRules.cards(GameState.player_save)
	host.state.draw_pile.assign(deck_cards)
	host.state.draw_pile.shuffle()
	host.state.discard_pile.clear()
	host.state.hand.clear()

func refresh_hand() -> void:
	if host.turn.phase != CombatTurnController.Phase.PLANNING:
		_sync_playing_resolution()
	refresh_hand_view()

## Refresco puramente visual: no avanza ni resuelve líneas en juego.
func refresh_hand_view() -> void:
	var turn := host.turn
	var state = host.state
	if turn.phase == CombatTurnController.Phase.PLANNING:
		turn.hand_view_indices.clear()
		for i in state.hand.size():
			if not turn.plan_slots.has(i):
				turn.hand_view_indices.append(i)
		host.hand_section.drag_source = "hand"
		host.hand_section.halves_mode = false
		host.hand_section.set_cards(turn.hand_view_indices.map(func(i): return state.hand[i]))
	else:
		host._wildcards.update_buttons()
		host.hand_section.drag_source = ""
		host.hand_section.halves_mode = true
		host.hand_section.set_cards(turn.turn_cards)
		for c in turn.turn_cards.size():
			for is_top in [true, false]:
				host.hand_section.set_half_enabled(c, is_top, turn.is_half_available(c, is_top, state.player_mp))
		_show_active_line()
	host.draw_pile_button.text = LocalizationState.t("combat.draw_pile", [state.draw_pile.size()])
	host.discard_pile_button.text = LocalizationState.t("combat.discard_pile", [state.discard_pile.size()])
	if host._preview_action != null and not state.turn_actions.has(host._preview_action):
		host.hide_card_preview()
	_update_plan_zone()

# ── Gestión de turnos ─────────────────────────────────────────────────────────
# Cada ronda: el jugador elige 2 cartas de la mano (superior de una + inferior
# de la otra). La iniciativa de la carta superior se compara con la del enemigo;
# menor actúa primero y el jugador gana los empates.

func start_planning() -> void:
	host.turn.begin_planning()
	host._wildcards.disarm()
	host.turn_order_bar.visible = false
	host.monster_card_view.visible = false
	host.monster_card_view.snap_home()
	host.end_turn_button.disabled = true
	host.move_mode_button.disabled = true
	host.hand_section.set_title(LocalizationState.t("combat.hand"))
	refresh_hand()
	host.update_ui()
	host.log_message(LocalizationState.t("combat.plan_hint"))

func on_hand_card_selected(index: int) -> void:
	match host.turn.phase:
		CombatTurnController.Phase.PLANNING:
			if not host.turn.try_plan_card(host.turn.hand_view_indices[index]):
				host.log_message(LocalizationState.t("combat.plan_max"))
				return
			refresh_hand()

func on_hand_half_selected(index: int, is_top: bool) -> void:
	var turn := host.turn
	var selection := turn.select_half(index, is_top, host.state.player_mp, _line_cap(), Combat.WILD_ATTACK, Combat.WILD_MOVE)
	match selection["kind"]:
		"unavailable":
			return
		"keep":
			host._wildcards.start_keep(index, is_top)
			return
		"item":
			host._wildcards.start_item(index, is_top)
			return
		"no_lines":
			host.log_message(LocalizationState.t("combat.no_lines"))
			return
	var is_wild: bool = selection["is_wild"]
	if is_wild:
		for line: CardActionLine in turn.playing.lines:
			line.name = LocalizationState.t("wildcard.name")
	host._wildcards.disarm()
	# Cambiar de mitad antes de hacer la primera línea no gasta nada.
	if host.player_actions.has_pending_selection():
		host.player_actions.cancel_selection()
	_begin_current_line()

## Entrega la próxima línea decidida por CombatTurnController a la capa que la
## ejecuta en el mapa. Los avisos y la selección siguen siendo responsabilidad
## de la escena.
func _begin_current_line() -> void:
	var turn := host.turn
	var next := turn.start_current_line(host.state.player_mp)
	for _i in next.get("skipped_for_mp", 0):
		host.log_message(LocalizationState.t("combat.line_no_mp"))
	if next["kind"] != "line":
		refresh_hand()
		return
	var line: CardActionLine = next["line"]
	host.state.turn_actions.assign([line])
	host.player_actions.start_line(line)
	turn.finish_starting_line()
	# refresh_hand sincroniza la línea si no pudo ni arrancar (p. ej. enredado).
	refresh_hand()

## Recuadra en la carta la línea en juego que se está usando. Los comodines
## reemplazan la mitad, así que no marcan nada en la carta.
func _show_active_line() -> void:
	var turn := host.turn
	if turn.playing == null or turn.playing.wild:
		return
	# Las líneas en juego son solo las activas: se busca su índice en la mitad.
	var source: CardAction = turn.playing.source
	var enabled_seen := -1
	for i in source.lines.size():
		var line: CardActionLine = source.lines[i]
		if line == null or not line.enabled:
			continue
		enabled_seen += 1
		if enabled_seen == turn.playing.index:
			host.hand_section.set_active_line(turn.playing.card, turn.playing.is_top, i)
			return

## Tope de líneas por mitad para la etapa del Youn (DeckRules.line_cap).
func _line_cap() -> int:
	return DeckRules.line_cap(YounData.get_active_stage(GameState.player_save))

## "Saltar acción": el controlador gasta la mitad; CombatPlayerActions cancela
## la selección y la próxima sincronización avanza a la siguiente línea.
func on_skip_line_pressed() -> void:
	var result := host.turn.skip_active_line()
	if not result["skipped"]:
		return
	_add_echoes(result.get("echo_card"))
	host.player_actions.cancel_selection()

## Sincroniza los efectos externos de una transición ya resuelta por el
## controlador: puntos de movimiento, ecos, mensajes y la siguiente selección.
func _sync_playing_resolution() -> void:
	var turn := host.turn
	if turn.playing == null:
		return
	var line: CardActionLine = turn.playing.lines[turn.playing.index]
	var result := turn.resolve_playing(host.state.turn_actions.has(line), host.player_actions.has_pending_selection())
	_add_echoes(result.get("echo_card"))
	host.state.player_mp -= result.get("mp_cost", 0)
	match result["kind"]:
		"abandoned":
			host.state.turn_actions.clear()
		"line_skipped":
			host.log_message(LocalizationState.t("combat.line_skipped"))
		"cap_reached":
			host.log_message(LocalizationState.t("combat.line_cap_reached", [result["cap"]]))
		"next_line":
			# CombatPlayerActions todavía puede estar terminando la línea anterior.
			_begin_current_line.call_deferred()

## Solo va contando: se acreditan al depósito al terminar la pelea (si se
## gana), en CombatResultFlow.
func _add_echoes(card: CardData) -> void:
	for echo_id in LaboratoryEchoes.echo_ids_for_card(card):
		host.state.echoes_earned[echo_id] = host.state.echoes_earned.get(echo_id, 0) + 1

func on_plan_slot_clicked(slot: int) -> void:
	if host.turn.phase != CombatTurnController.Phase.PLANNING:
		return
	host.turn.clear_plan_slot(slot)
	refresh_hand()

func on_plan_slot_dropped(slot: int, data: Dictionary) -> void:
	if host.turn.phase != CombatTurnController.Phase.PLANNING:
		return
	host.turn.drop_plan_slot(slot, data, host.turn.hand_view_indices)
	refresh_hand()

func _update_plan_zone() -> void:
	var turn := host.turn
	host.plan_zone.visible = turn.phase == CombatTurnController.Phase.PLANNING
	if not host.plan_zone.visible:
		return
	var cards := turn.plan_slots.map(func(i): return host.state.hand[i] if i >= 0 else null)
	var initiative: int = turn.player_initiative(cards[0]) if cards[0] != null else -1
	# Con mazo, la carta del enemigo (y su iniciativa) se revela al confirmar.
	var enemy_initiative := "?" if host.enemy_ai.monster_deck != null else str(host.enemy_ai.initiative)
	host.plan_zone.set_state(cards, initiative, enemy_initiative, turn.initiative_shift, _max_initiative_shift())

func _max_initiative_shift() -> int:
	return YounStatRules.initiative_shift(CardScaling.player_stats())

func on_initiative_shift_requested(delta: int) -> void:
	if host.turn.phase != CombatTurnController.Phase.PLANNING:
		return
	host.turn.adjust_initiative(delta, _max_initiative_shift())
	_update_plan_zone()

func commit_plan(lead_index: int, second_index: int) -> void:
	var turn := host.turn
	var state = host.state
	if turn.phase != CombatTurnController.Phase.PLANNING:
		return
	if lead_index < 0 or second_index < 0 or lead_index == second_index:
		return
	if lead_index >= state.hand.size() or second_index >= state.hand.size():
		return
	turn.commit_plan(state.hand, lead_index, second_index)
	state.turn_actions.clear()

	var player_initiative := turn.player_initiative(turn.turn_cards[0])
	var monster_card: MonsterCard = host.enemy_ai.draw_card()
	host.log_message(LocalizationState.t("combat.initiative", [player_initiative, host.enemy_ai.initiative]))
	host.hand_section.set_title(LocalizationState.t("combat.actions"))
	turn.build_turn_order(host._player_name, player_initiative, host._enemy_name, host.enemy_ai.initiative)
	var enemy_first: bool = not turn.turn_order[0]["is_player"]
	# Si el enemigo no va primero, actúa cuando el jugador termina su turno.
	turn.enemy_pending = not enemy_first
	host.log_message(LocalizationState.t("combat.enemy_first" if enemy_first else "combat.player_first"))

	# Todo revelado: se espera a que el jugador arranque la ronda.
	turn.phase = CombatTurnController.Phase.REVEAL
	refresh_hand()
	host.turn_order_bar.show_order(turn.turn_order, -1)
	await _reveal_and_wait(monster_card)

	if enemy_first:
		turn.phase = CombatTurnController.Phase.ENEMY
		host.turn_order_bar.show_order(turn.turn_order, 0)
		await host.enemy_ai.take_turn()
		if host._result_flow.check_combat_end():
			return

	host.turn_order_bar.show_order(turn.turn_order, turn.turn_order.find_custom(func(e): return e["is_player"]))
	turn.phase = CombatTurnController.Phase.ACTING
	host.end_turn_button.disabled = false
	host.move_mode_button.disabled = false
	refresh_hand()
	host.update_ui()
	host.log_message(LocalizationState.t("combat.acting_hint"))

## Muestra la carta del enemigo grande en el centro con "Comenzar ronda" debajo,
## espera el botón y manda la carta a su lugar de arriba a la izquierda.
func _reveal_and_wait(monster_card: MonsterCard) -> void:
	await host.enemy_reveal.present_and_wait(monster_card, host.enemy_ai.monster_deck, host.enemy_ai.round_options,
		Combat.REVEAL_CARD_ZOOM, Combat.CARD_BACK_SCALE, Combat.CARD_SLOT_SPACING)

func on_end_turn_pressed() -> void:
	var turn := host.turn
	if turn.phase != CombatTurnController.Phase.ACTING:
		return
	turn.phase = CombatTurnController.Phase.ENEMY
	host.end_turn_button.disabled = true
	host.move_mode_button.disabled = true
	host.player_actions.reset()
	host.state.turn_actions.clear()
	turn.clear_action_state()
	host._wildcards.close_item_picker()
	host._pile_popup.close()
	host._wildcards.disarm()
	refresh_hand()
	if turn.enemy_pending:
		host.turn_order_bar.show_order(turn.turn_order, turn.turn_order.find_custom(func(e): return not e["is_player"]))
		await host.get_tree().create_timer(Combat.TURN_ORDER_PAUSE).timeout
		await host.enemy_ai.take_turn()
		if host._result_flow.check_combat_end():
			return
	await _reset_turn()
	if host.state.player_hp <= 0 or host.state.enemy_hp <= 0:
		return
	start_planning()

func _reset_turn() -> void:
	for event in host.round_resolver.build_events(host.state, host.map_area):
		if await _resolve_round_event(event):
			return

	host.player_actions.reset()
	host.deck_manager.reset_turn(Combat.HAND_SIZE, host.turn.kept_indices)
	host.turn.kept_indices.clear()
	host.turn.turn_hand_indices.clear()
	refresh_hand()
	host.update_ui()

## Aplica la parte visible de un evento de fin de ronda. Devuelve true si el
## combate terminó y la secuencia no debe continuar.
func _resolve_round_event(event: CombatRoundEvent) -> bool:
	match event.kind:
		"tree_drop":
			if event.hit:
				host.log_message(LocalizationState.t("combat.tree_drop.enemy_hit", [event.damage]))
				await host._damage.deal_to_enemy(event.damage, false, CombatState.FISICO)
				if host._result_flow.check_combat_end():
					return true
			else:
				host.log_message(LocalizationState.t("combat.tree_drop.descend"))
			host.player_actions.apply_player_zone_effects(host.map_area.player_pos, host.map_area.player_pos)
		"delayed_zone":
			if await _resolve_delayed_zone_event(event):
				return true
		"tick_map_effects":
			host.map_area.interactions.tick_puddles()
			host.map_area.interactions.tick_trees()
		"status_damage":
			host.log_message(LocalizationState.t(event.damage_log_key, [event.damage]))
			await host._damage.deal_to_player(event.damage, true, event.damage_type)
			if host._result_flow.check_combat_end():
				return true
			_log_expired_status(host.round_resolver.finish_status_event(host.state, event))
		"status_duration":
			_log_expired_status(host.round_resolver.finish_status_event(host.state, event))
	return false

func _resolve_delayed_zone_event(event: CombatRoundEvent) -> bool:
	var hit: Dictionary = event.zone_hit
	match event.target:
		"enemy":
			host.log_message(LocalizationState.t("combat.delayed_zone.enemy_hit", [hit["name"], hit["damage"]]))
			await host._damage.deal_to_enemy(hit["damage"], true, CombatState.MAGICO)
			if host._result_flow.check_combat_end():
				return true
			_log_delayed_zone_impact(host.round_resolver.apply_delayed_zone_impact(host.state, event), true)
		"player":
			host.log_message(LocalizationState.t("combat.delayed_zone.player_hit", [hit["name"], hit["damage"]]))
			await host._damage.deal_to_player(hit["damage"], true, CombatState.MAGICO)
			if host._result_flow.check_combat_end():
				return true
			_log_delayed_zone_impact(host.round_resolver.apply_delayed_zone_impact(host.state, event), false)
		"none":
			host.log_message(LocalizationState.t("combat.delayed_zone.miss", [hit["name"]]))
	return false

func _log_delayed_zone_impact(impact: Array, on_enemy: bool) -> void:
	if not impact.is_empty() and impact[1] > 0:
		var key := "combat.status.enemy_applied" if on_enemy else "combat.status.player_applied"
		var status := str(impact[0])
		var status_key := "combat.status_name." + status
		var status_name: String = LocalizationState.t(status_key) if LocalizationState.has_key(status_key) \
			else str(CombatPlayerActions.STATUS_NAMES.get(status, status))
		host.log_message(LocalizationState.t(key, [status_name, impact[1]]))

func _log_expired_status(key: String) -> void:
	if not key.is_empty():
		host.log_message(LocalizationState.t(key))
