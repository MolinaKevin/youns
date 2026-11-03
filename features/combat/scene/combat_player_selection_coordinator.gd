class_name CombatPlayerSelectionCoordinator
extends RefCounted

## Coordina la elección de carta y el despacho al resolver pendiente.
## Las reglas y el estado siguen perteneciendo a CombatPlayerActions; este
## objeto sólo concentra el flujo de entrada de la UI.

var host

func _init(p_host) -> void:
	host = p_host

func play_as_move(index: int) -> void:
	var card = host.state.turn_actions[index]
	if host.state.player_overwatch_active:
		host.state.player_overwatch_active = false
		host.board.selection.actions.overwatch.clear_overwatch_zone()
		host.emit_log("combat.log.player.overwatch_cancelled")
	if host.state.player_entangled_turns > 0:
		host.emit_log("combat.log.player.entangled_cannot_move", [host.state.player_entangled_turns])
		host.card_preview_hide_requested.emit()
		return
	if host.state.player_frozen_turns > 0:
		host.emit_log("combat.log.player.frozen_cannot_move", [host.state.player_frozen_turns])
		host.card_preview_hide_requested.emit()
		return
	if host.state.player_in_tree:
		host.emit_log("combat.log.player.in_tree_cannot_move")
		host.card_preview_hide_requested.emit()
		return
	host.card_preview_show_requested.emit(card)
	var penalty: int = host._move_penalty()
	var effective_range: int = maxi(1, CardActionLine.movement_cells_for_modules(host.MOVE_MODE_MODULES) - penalty)
	if penalty > 0:
		host.emit_log("combat.log.player.movement_reduced")
	host._move_action.configure(index, effective_range)
	host.set_current_action(host._move_action)
	host.emit_log("combat.log.player.move_mode", [CardActionLine.movement_modules_label_for_cells(effective_range)])

func play_card(index: int) -> void:
	var card = host.state.turn_actions[index]
	if host.state.player_overwatch_active and card.card_type != CardActionLine.TYPE_OVERWATCH:
		host.state.player_overwatch_active = false
		host.board.selection.actions.overwatch.clear_overwatch_zone()
		host.emit_log("combat.log.player.overwatch_cancelled")
	host.card_preview_show_requested.emit(card)
	if host.state.player_in_tree and card.card_type in host.TREE_BLOCKED_LINES:
		host.emit_log("combat.log.player.in_tree_cannot_move")
		host.card_preview_hide_requested.emit()
		return
	match card.card_type:
		CardActionLine.TYPE_MOVE:
			host.start_move_selection("hand", index, card.movement_range_cells(), card.name)
		CardActionLine.TYPE_MELEE_ATTACK:
			var r: int = card.primary_range_cells() if card.primary_range_cells() > 0 else CardActionLine.cells_for_modules(host.MELEE_RANGE_MODULES)
			host.start_range_attack_selection(index, card, r)
		CardActionLine.TYPE_RANGE_ATTACK:
			host.start_range_attack_selection(index, card, card.primary_range_cells())
		CardActionLine.TYPE_GRENADE:
			host.start_grenade_selection(index, card)
		CardActionLine.TYPE_TRAP_PLACE:
			host.start_trap_selection(index, card, true)
		CardActionLine.TYPE_TRAP_THROW:
			host.start_trap_selection(index, card, false)
		CardActionLine.TYPE_BLOCK, CardActionLine.TYPE_WARD, CardActionLine.TYPE_MP_RESTORE, CardActionLine.TYPE_COUNTER, CardActionLine.TYPE_NOVA, CardActionLine.TYPE_HEAL, CardActionLine.TYPE_ENCHANT:
			host.start_self_selection(index, card)
		CardActionLine.TYPE_ELEMENT_BOLT, CardActionLine.TYPE_CHAIN_BOLT, CardActionLine.TYPE_DELAYED_AREA, CardActionLine.TYPE_CONE_BLAST, CardActionLine.TYPE_CURSE, CardActionLine.TYPE_BLINK, CardActionLine.TYPE_PUDDLE_HOP, CardActionLine.TYPE_TREE_CLIMB:
			host._start_spell_selection(index, card)
		CardActionLine.TYPE_ROCK_JUMP:
			host.start_rock_jump_selection(index, card)
		CardActionLine.TYPE_PUSH, CardActionLine.TYPE_PULL, CardActionLine.TYPE_ANCHOR:
			host.start_push_selection(index, card)
		CardActionLine.TYPE_BREAK, CardActionLine.TYPE_MODULE_PUSH, CardActionLine.TYPE_BUILD, CardActionLine.TYPE_MODULE_THROW, CardActionLine.TYPE_COLLAPSE:
			host._module_action.start(index, card)
			host.set_current_action(host._module_action)
		CardActionLine.TYPE_PUDDLE:
			host.start_puddle_selection(index, card)
		CardActionLine.TYPE_OVERWATCH:
			host.start_overwatch_selection(index, card)
