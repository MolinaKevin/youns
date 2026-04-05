class_name CombatPlayerActions
extends RefCounted

const MOVE_MODE_RANGE := 10

var state
var combat: Node

var move_mode := false

var pending_move_section := ""
var pending_move_index := -1
var pending_move_range := 0
var pending_move_started := false

var pending_attack_section := ""
var pending_attack_index := -1
var pending_attack_range := 0

var pending_grenade_index := -1
var pending_trap_index := -1

var pending_cell := Vector2i(-1, -1)

func setup(p_combat: Node, p_state) -> void:
	combat = p_combat
	state = p_state

# ── Card selection ────────────────────────────────────────────────────────────

func _on_card_selected(card: CardData) -> void:
	var index: int = state.hand.find(card)
	if index == -1:
		return
	if move_mode:
		play_as_move(index)
	else:
		play_card(index)

func _on_move_mode_toggled(pressed: bool) -> void:
	move_mode = pressed
	if not pressed:
		clear_pending_move()

func play_as_move(index: int) -> void:
	var card = state.hand[index]
	if card.cost > state.player_energy:
		combat.log_message("Not enough energy.")
		return
	pending_move_section = "hand"
	pending_move_index = index
	pending_move_range = MOVE_MODE_RANGE
	combat.map_area.start_move_selection(MOVE_MODE_RANGE)
	combat.log_message("Move mode: choose a tile up to %d spaces away." % MOVE_MODE_RANGE)

func play_card(index: int) -> void:
	var card = state.hand[index]
	if card.cost > state.player_energy:
		combat.log_message("Not enough energy for %s." % card.name)
		return

	match card.card_type:
		"move":
			start_move_selection("hand", index, card.card_range, card.cost, card.name)
		"melee_attack":
			play_attack_card(index, card, true)
		"range_attack":
			start_range_attack_selection(index, card)
		"targeted_attack":
			play_attack_card(index, card, false)
		"grenade":
			start_grenade_selection(index, card)
		"trap_place":
			start_trap_selection(index, card, true)
		"trap_throw":
			start_trap_selection(index, card, false)
		"block":
			state.player_block += card.block_amount
			state.player_energy -= card.cost
			combat.log_message("Played %s. Block: %d" % [card.name, state.player_block])
			state.discard_pile.append(state.hand[index])
			state.hand.remove_at(index)
			combat.refresh_hand()
			combat.update_ui()

# ── Selection starters ────────────────────────────────────────────────────────

func start_move_selection(section_name: String, index: int, move_range: int, energy_cost: int, card_name: String) -> void:
	if energy_cost > state.player_energy:
		combat.log_message("Not enough energy for %s." % card_name)
		return
	pending_move_section = section_name
	pending_move_index = index
	pending_move_range = move_range
	combat.map_area.start_move_selection(move_range)
	combat.log_message("Selected %s. Choose a tile up to %d spaces away." % [card_name, move_range])

func start_range_attack_selection(index: int, card: CardData) -> void:
	pending_attack_section = "hand"
	pending_attack_index = index
	pending_attack_range = card.card_range
	combat.map_area.start_attack_selection(card.card_range)
	combat.log_message("Selected %s. Click to confirm attack (range: %d)." % [card.name, card.card_range])

func start_grenade_selection(index: int, card: CardData) -> void:
	if card.cost > state.player_energy:
		combat.log_message("Not enough energy for %s." % card.name)
		return
	pending_grenade_index = index
	combat.map_area.start_trap_placement(card.throw_range)
	combat.log_message("Selected %s. Choose a tile up to %d spaces away (bounce: %.1f)." % [card.name, card.throw_range, card.bounce])

func start_trap_selection(index: int, card: CardData, nearby: bool) -> void:
	if card.cost > state.player_energy:
		combat.log_message("Not enough energy for %s." % card.name)
		return
	pending_trap_index = index
	if nearby:
		combat.map_area.start_trap_placement(8)
		combat.log_message("Place %s nearby (range 8)." % card.name)
	else:
		combat.map_area.start_trap_placement(card.throw_range)
		combat.log_message("Throw %s — choose a tile up to %d spaces away." % [card.name, card.throw_range])

# ── Map tile selected & confirm popup ────────────────────────────────���────────

func _on_map_tile_selected(cell: Vector2i) -> void:
	var has_pending := (
		pending_trap_index >= 0 or
		pending_grenade_index >= 0 or
		pending_attack_index >= 0 or
		pending_move_index >= 0 or
		pending_move_started
	)
	if not has_pending:
		return

	pending_cell = cell
	if (pending_move_index >= 0 or pending_move_started) and combat.map_area.has_method("show_move_preview"):
		combat.map_area.show_move_preview(cell)
	combat.confirm_fin_button.visible = pending_move_started
	combat.confirm_popup.visible = true

func _on_confirm_yes() -> void:
	combat.confirm_popup.visible = false
	var cell := pending_cell
	pending_cell = Vector2i(-1, -1)
	_execute_tile_action(cell)
	if combat.map_area.has_method("clear_move_preview"):
		combat.map_area.clear_move_preview()

func _on_confirm_no() -> void:
	combat.confirm_popup.visible = false
	if combat.map_area.has_method("clear_move_preview"):
		combat.map_area.clear_move_preview()
	pending_cell = Vector2i(-1, -1)

func _on_confirm_fin() -> void:
	combat.confirm_popup.visible = false
	if combat.map_area.has_method("clear_move_preview"):
		combat.map_area.clear_move_preview()
	pending_cell = Vector2i(-1, -1)
	_finish_movement()

func _on_end_move_pressed() -> void:
	_finish_movement()

func _finish_movement() -> void:
	combat.end_move_button.visible = false
	clear_pending_move()
	if move_mode:
		combat.move_mode_button.button_pressed = false
	combat.refresh_hand()
	combat.update_ui()

# ── Execute actions ───────────────────────────────────────────────────────────

func _execute_tile_action(cell: Vector2i) -> void:
	if pending_trap_index >= 0:
		_place_trap(cell)
		return

	if pending_grenade_index >= 0:
		_throw_grenade(cell)
		return

	if pending_attack_index >= 0:
		_confirm_range_attack()
		return

	if pending_move_index < 0 and not pending_move_started:
		return

	if not combat.map_area.has_method("try_move_player_to"):
		return

	var dist_moved: float = combat.map_area.get_path_cost(cell)
	var path: Array[Vector2i] = combat.map_area.move_preview_path.duplicate()
	var moved: bool = combat.map_area.try_move_player_to(cell, pending_move_range)
	if not moved:
		combat.log_message("Invalid move.")
		return

	var trap_dmg: int = combat.map_area.check_and_trigger_traps_along_path(path, combat.map_area.player_shape)
	if trap_dmg > 0:
		combat.deal_damage_to_player(trap_dmg)
		combat.log_message("Pisaste una trampa en el camino! %d daño." % trap_dmg)
		if combat.check_combat_end():
			return

	if not pending_move_started:
		var card = state.hand[pending_move_index]
		state.player_energy -= card.cost
		combat.log_message("Played %s." % card.name)
		state.discard_pile.append(state.hand[pending_move_index])
		state.hand.remove_at(pending_move_index)
		pending_move_index = -1
		pending_move_started = true

	var remaining := maxi(0, pending_move_range - roundi(dist_moved))
	if remaining > 0:
		combat.log_message("Rango restante: %d" % remaining)
		pending_move_range = remaining
		combat.map_area.start_move_selection(remaining)
		combat.end_move_button.visible = true
		combat.refresh_hand()
		combat.update_ui()
	else:
		combat.end_move_button.visible = false
		clear_pending_move()
		if move_mode:
			combat.move_mode_button.button_pressed = false
		combat.refresh_hand()
		combat.update_ui()

func _place_trap(cell: Vector2i) -> void:
	var card: CardData = state.hand[pending_trap_index]
	var is_nearby := card.card_type == "trap_place"

	if is_nearby and combat.map_area.movement_distance(combat.map_area.player_pos, cell) > 8.0:
		combat.log_message("Too far to place %s." % card.name)
		return

	if not is_nearby and card.throw_range > 0 and combat.map_area.movement_distance(combat.map_area.player_pos, cell) > float(card.throw_range):
		combat.log_message("Too far to throw %s." % card.name)
		return

	state.player_energy -= card.cost
	combat.map_area.place_trap(cell, card.card_range, card.damage, card.name)
	combat.log_message("Placed %s at (%d,%d)." % [card.name, cell.x, cell.y])
	state.discard_pile.append(state.hand[pending_trap_index])
	state.hand.remove_at(pending_trap_index)
	pending_trap_index = -1
	combat.map_area.clear_trap_placement()
	combat.refresh_hand()
	combat.update_ui()

func _throw_grenade(target: Vector2i) -> void:
	var card: CardData = state.hand[pending_grenade_index]

	if card.throw_range > 0 and combat.map_area.movement_distance(combat.map_area.player_pos, target) > float(card.throw_range):
		combat.log_message("Too far to throw %s." % card.name)
		return

	combat.map_area.clear_trap_placement()
	var landing: Vector2i = combat.map_area.calculate_grenade_landing(combat.map_area.player_pos, target, card.bounce)
	combat.map_area.show_grenade_preview(landing, card.card_range)

	if combat.map_area.is_enemy_in_explosion(landing, card.card_range):
		state.player_energy -= card.cost
		combat.deal_damage_to_enemy(card.damage)
		combat.log_message("%s lands at (%d,%d) — %d damage!" % [card.name, landing.x, landing.y, card.damage])
	else:
		state.player_energy -= card.cost
		combat.log_message("%s lands at (%d,%d) — miss!" % [card.name, landing.x, landing.y])

	state.discard_pile.append(state.hand[pending_grenade_index])
	state.hand.remove_at(pending_grenade_index)
	pending_grenade_index = -1

	await combat.get_tree().create_timer(0.6).timeout
	combat.map_area.clear_grenade_preview()
	combat.refresh_hand()
	combat.update_ui()
	combat.check_combat_end()

func _confirm_range_attack() -> void:
	if pending_attack_index < 0 or pending_attack_index >= state.hand.size():
		clear_pending_attack()
		return

	var card = state.hand[pending_attack_index]
	if not combat.map_area.is_enemy_in_attack_range(pending_attack_range):
		combat.log_message("%s missed. Enemy out of range." % card.name)
		clear_pending_attack()
		return

	state.player_energy -= card.cost
	combat.deal_damage_to_enemy(card.damage)
	combat.log_message("Played %s for %d damage." % [card.name, card.damage])
	state.discard_pile.append(state.hand[pending_attack_index])
	state.hand.remove_at(pending_attack_index)
	clear_pending_attack()
	combat.refresh_hand()
	combat.update_ui()
	combat.check_combat_end()

func play_attack_card(index: int, card: CardData, requires_melee: bool) -> void:
	if requires_melee:
		if not combat.map_area.has_method("is_enemy_in_melee_range"):
			combat.log_message("MapArea is missing melee logic.")
			return
		if not combat.map_area.is_enemy_in_melee_range():
			combat.log_message("%s failed. Enemy is not in melee range." % card.name)
			return

	state.player_energy -= card.cost
	combat.deal_damage_to_enemy(card.damage)
	combat.log_message("Played %s for %d damage." % [card.name, card.damage])
	state.discard_pile.append(state.hand[index])
	state.hand.remove_at(index)
	combat.refresh_hand()
	combat.update_ui()
	combat.check_combat_end()

# ── Clear pending ─────────────────────────────────────────────────────────────

func clear_pending_attack() -> void:
	pending_attack_section = ""
	pending_attack_index = -1
	pending_attack_range = 0
	combat.map_area.clear_attack_selection()

func clear_pending_move() -> void:
	pending_move_section = ""
	pending_move_index = -1
	pending_move_range = 0
	pending_move_started = false
	combat.end_move_button.visible = false
	if combat.map_area.has_method("clear_move_selection"):
		combat.map_area.clear_move_selection()

func reset() -> void:
	clear_pending_move()
	clear_pending_attack()
	pending_grenade_index = -1
	pending_trap_index = -1
	combat.map_area.clear_grenade_preview()
	combat.map_area.clear_trap_placement()
	combat.move_mode_button.button_pressed = false
	move_mode = false
