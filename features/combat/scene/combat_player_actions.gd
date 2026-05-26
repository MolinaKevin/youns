class_name CombatPlayerActions
extends RefCounted

const MOVE_MODE_RANGE := 3
const MELEE_RANGE     := 2

var state
var map_area: Node

var _deal_damage_to_enemy: Callable
var _deal_damage_to_player: Callable
var _check_combat_end: Callable

var move_mode := false

var pending_move_section := ""
var pending_move_index := -1
var pending_move_range := 0
var pending_move_started := false

var pending_attack_section := ""
var pending_attack_index := -1
var pending_attack_range := 0

var pending_grenade_index := -1
var pending_trap_index    := -1
var pending_self_index    := -1

var pending_jump_index:    int     = -1
var pending_jump_phase:    int     = 0
var pending_jump_rock_pos: Vector2 = Vector2(-1.0, -1.0)
var pending_jump_card:     CardData = null

var pending_push_index: int      = -1
var pending_push_phase: int      = 0
var pending_push_card:  CardData = null

var pending_puddle_index: int = -1

var pending_cell := Vector2(-1.0, -1.0)

signal log_requested(text: String)
signal hand_refresh_requested()
signal ui_update_requested()
signal card_preview_show_requested(card: CardData)
signal card_preview_hide_requested()
signal confirm_popup_show_requested(show_fin_button: bool)
signal confirm_popup_hide_requested()
signal end_move_button_visible_changed(visible: bool)
signal move_mode_button_reset_requested()

func setup(p_state, p_map_area: Node, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	_deal_damage_to_enemy = p_damage_enemy
	_deal_damage_to_player = p_damage_player
	_check_combat_end = p_check_end

# ── Card selection ────────────────────────────────────────────────────────────

func _on_card_selected(card: CardData) -> void:
	if _has_pending_selection():
		cancel_selection()
	var index: int = state.hand.find(card)
	if index == -1:
		return
	if move_mode:
		play_as_move(index)
	else:
		play_card(index)

func _has_pending_selection() -> bool:
	return (
		pending_attack_index >= 0 or
		pending_move_index >= 0 or
		pending_move_started or
		pending_trap_index >= 0 or
		pending_grenade_index >= 0 or
		pending_self_index >= 0 or
		pending_jump_index >= 0 or
		pending_push_index >= 0 or
		pending_puddle_index >= 0
	)

func _on_move_mode_toggled(pressed: bool) -> void:
	move_mode = pressed
	if not pressed:
		clear_pending_move()

func play_as_move(index: int) -> void:
	var card = state.hand[index]
	if card.cost > state.player_energy:
		log_requested.emit("Not enough energy.")
		return
	card_preview_show_requested.emit(card)
	var effective_range := MOVE_MODE_RANGE
	if state.player_wet_turns > 0:
		effective_range = maxi(1, MOVE_MODE_RANGE - 1)
		log_requested.emit("Estás mojado: movimiento reducido a %d." % effective_range)
	pending_move_section = "hand"
	pending_move_index = index
	pending_move_range = effective_range
	map_area.start_move_selection(effective_range)
	log_requested.emit("Move mode: choose a tile up to %d spaces away." % effective_range)

func play_card(index: int) -> void:
	var card = state.hand[index]
	if card.cost > state.player_energy:
		log_requested.emit("Not enough energy for %s." % card.name)
		return

	card_preview_show_requested.emit(card)
	match card.card_type:
		"move":
			start_move_selection("hand", index, card.card_range, card.cost, card.name)
		"melee_attack":
			var r: int = card.card_range if card.card_range > 0 else MELEE_RANGE
			start_range_attack_selection(index, card, r)
		"targeted_attack":
			var r: int = card.card_range if card.card_range > 0 else MELEE_RANGE
			start_range_attack_selection(index, card, r)
		"range_attack":
			start_range_attack_selection(index, card, card.card_range)
		"grenade":
			start_grenade_selection(index, card)
		"trap_place":
			start_trap_selection(index, card, true)
		"trap_throw":
			start_trap_selection(index, card, false)
		"block":
			start_self_selection(index, card)
		"rock_jump":
			start_rock_jump_selection(index, card)
		"push":
			start_push_selection(index, card)
		"puddle":
			start_puddle_selection(index, card)

# ── Selection starters ────────────────────────────────────────────────────────

func start_move_selection(section_name: String, index: int, move_range: int, energy_cost: int, card_name: String) -> void:
	if energy_cost > state.player_energy:
		log_requested.emit("Not enough energy for %s." % card_name)
		return
	var effective_range := move_range
	if state.player_wet_turns > 0:
		effective_range = maxi(1, move_range - 1)
		log_requested.emit("Estás mojado: movimiento reducido a %d." % effective_range)
	pending_move_section = section_name
	pending_move_index = index
	pending_move_range = effective_range
	map_area.start_move_selection(effective_range)
	log_requested.emit("Selected %s. Choose a tile up to %d spaces away." % [card_name, effective_range])

func start_range_attack_selection(index: int, card: CardData, range_override: int = 0) -> void:
	pending_attack_section = "hand"
	pending_attack_index   = index
	pending_attack_range   = range_override if range_override > 0 else card.card_range
	map_area.start_attack_selection(pending_attack_range)

func start_grenade_selection(index: int, card: CardData) -> void:
	if card.cost > state.player_energy:
		log_requested.emit("Not enough energy for %s." % card.name)
		return
	pending_grenade_index = index
	map_area.start_trap_placement(card.throw_range)
	log_requested.emit("Selected %s. Choose a tile up to %d spaces away (bounce: %.1f)." % [card.name, card.throw_range, card.bounce])

func start_trap_selection(index: int, card: CardData, nearby: bool) -> void:
	if card.cost > state.player_energy:
		log_requested.emit("Not enough energy for %s." % card.name)
		return
	pending_trap_index = index
	if nearby:
		map_area.start_trap_placement(8)
		log_requested.emit("Place %s nearby (range 8)." % card.name)
	else:
		map_area.start_trap_placement(card.throw_range)
		log_requested.emit("Throw %s — choose a tile up to %d spaces away." % [card.name, card.throw_range])

func start_self_selection(index: int, card: CardData) -> void:
	if card.cost > state.player_energy:
		log_requested.emit("Not enough energy for %s." % card.name)
		return
	pending_self_index = index
	map_area.start_self_highlight()

func start_push_selection(index: int, card: CardData) -> void:
	if card.cost > state.player_energy:
		log_requested.emit("No tenés energía para %s." % card.name)
		return
	pending_push_index = index
	pending_push_phase = 0
	pending_push_card  = card
	map_area.start_push_enemy_selection(float(card.card_range))
	log_requested.emit("Seleccioná al enemigo para agarrarlo.")

func start_puddle_selection(index: int, card: CardData) -> void:
	if card.cost > state.player_energy:
		log_requested.emit("No tenés energía para %s." % card.name)
		return
	pending_puddle_index = index
	map_area.start_puddle_placement(float(card.throw_range))
	log_requested.emit("Elegí dónde lanzar el charco (rango %d)." % card.throw_range)

func start_rock_jump_selection(index: int, card: CardData) -> void:
	if card.cost > state.player_energy:
		log_requested.emit("No tenés energía para %s." % card.name)
		return
	var rocks: Array[Dictionary] = map_area.get_rocks_in_range(map_area.player_pos, float(card.card_range))
	if rocks.is_empty():
		log_requested.emit("%s: no hay piedras al alcance." % card.name)
		card_preview_hide_requested.emit()
		return
	pending_jump_index = index
	pending_jump_phase = 0
	pending_jump_card  = card
	map_area.start_rock_jump_selection(float(card.card_range))
	log_requested.emit("Seleccioná una piedra dentro de %d espacios." % card.card_range)

# ── Map tile selected & confirm popup ─────────────────────────────────────────

func _on_position_selected(pos: Vector2) -> void:
	var has_pending := (
		pending_trap_index >= 0 or
		pending_grenade_index >= 0 or
		pending_attack_index >= 0 or
		pending_move_index >= 0 or
		pending_move_started or
		pending_self_index >= 0 or
		pending_jump_index >= 0 or
		pending_push_index >= 0 or
		pending_puddle_index >= 0
	)
	if not has_pending:
		return

	if pending_puddle_index >= 0:
		pending_cell = pos
		confirm_popup_show_requested.emit(false)
		return

	if pending_self_index >= 0:
		if map_area.is_click_on_player(pos):
			_confirm_self_action()
		return

	if pending_push_index >= 0:
		if pending_push_phase == 0:
			if not map_area.is_enemy_in_attack_range(float(pending_push_card.card_range)):
				log_requested.emit("El enemigo está demasiado lejos para agarrarlo.")
				return
			if not map_area.is_click_on_enemy(pos):
				return
			pending_push_phase = 1
			map_area.start_push_cone(float(pending_push_card.throw_range))
			log_requested.emit("Elegí hacia dónde empujar al enemigo.")
			return
		else:
			if not map_area.is_pos_in_push_cone(pos, float(pending_push_card.throw_range)):
				return
			pending_cell = pos
			confirm_popup_show_requested.emit(false)
			return

	if pending_jump_index >= 0:
		if pending_jump_phase == 0:
			var rock: Dictionary = map_area.get_rock_near(pos)
			if rock.is_empty():
				return
			pending_jump_rock_pos = rock["pos"]
			pending_jump_phase = 1
			map_area.start_jump_landing_selection(pending_jump_rock_pos, float(pending_jump_card.throw_range))
			log_requested.emit("Piedra en (%.1f, %.1f). Elegí dónde aterrizar." % [pending_jump_rock_pos.x, pending_jump_rock_pos.y])
			return
		else:
			if pending_jump_rock_pos.distance_to(pos) > float(pending_jump_card.throw_range):
				return
			if map_area._tile_in_obstacle(pos, 0):
				return
			pending_cell = pos
			confirm_popup_show_requested.emit(false)
			return

	pending_cell = pos
	var is_move_pending := pending_move_index >= 0 or pending_move_started
	if is_move_pending:
		var player: Vector2 = map_area.get("player_pos")
		if player.distance_to(pos) > pending_move_range:
			return
		if map_area._tile_in_obstacle(pos, map_area.player_elevation):
			return
		if map_area.player_elevation == 0 and not map_area.has_line_of_sight(player, pos):
			return
		var cost: float = map_area.compute_path(player, pos, map_area.player_elevation)
		if cost > pending_move_range + 1.5:
			return
		map_area.show_path_preview(player, pos)
	confirm_popup_show_requested.emit(pending_move_started)

func _on_confirm_yes() -> void:
	confirm_popup_hide_requested.emit()
	var cell := pending_cell
	pending_cell = Vector2(-1.0, -1.0)
	map_area.clear_path_preview()
	_execute_tile_action(cell)

func _on_confirm_no() -> void:
	confirm_popup_hide_requested.emit()
	map_area.clear_path_preview()
	pending_cell = Vector2(-1.0, -1.0)

func _on_confirm_fin() -> void:
	confirm_popup_hide_requested.emit()
	map_area.clear_path_preview()
	pending_cell = Vector2(-1.0, -1.0)
	_finish_movement()

func _on_end_move_pressed() -> void:
	_finish_movement()

func _finish_movement() -> void:
	card_preview_hide_requested.emit()
	end_move_button_visible_changed.emit(false)
	clear_pending_move()
	if move_mode:
		move_mode_button_reset_requested.emit()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

# ── Execute actions ───────────────────────────────────────────────────────────

func _execute_tile_action(cell: Vector2) -> void:
	if pending_trap_index >= 0:
		_place_trap(cell)
		return

	if pending_grenade_index >= 0:
		_throw_grenade(cell)
		return

	if pending_attack_index >= 0:
		_confirm_range_attack()
		return

	if pending_puddle_index >= 0:
		_execute_puddle(cell)
		return

	if pending_push_index >= 0:
		_execute_push(cell)
		return

	if pending_jump_index >= 0:
		_execute_jump_attack(cell)
		return

	if pending_move_index < 0 and not pending_move_started:
		return

	if not map_area.has_method("try_move_player_to"):
		return

	var move_from: Vector2 = map_area.player_pos
	var dist_moved: float = map_area.get_path_cost(cell)
	var moved: bool = map_area.try_move_player_to(cell, pending_move_range)
	if not moved:
		log_requested.emit("Invalid move.")
		return

	if map_area.is_segment_in_puddle(move_from, map_area.player_pos):
		state.player_wet_turns = 3
		log_requested.emit("¡Pisaste el charco! Estás mojado por 3 turnos.")

	var trap_dmg: int = map_area.check_and_trigger_traps_along_path(map_area.player_pos, cell)
	if trap_dmg > 0:
		_deal_damage_to_player.call(trap_dmg)
		log_requested.emit("Pisaste una trampa en el camino! %d daño." % trap_dmg)
		if _check_combat_end.call():
			return

	if not pending_move_started:
		var card = state.hand[pending_move_index]
		state.player_energy -= card.cost
		log_requested.emit("Played %s." % card.name)
		state.discard_pile.append(state.hand[pending_move_index])
		state.hand.remove_at(pending_move_index)
		pending_move_index = -1
		pending_move_started = true

	var remaining := maxi(0, pending_move_range - roundi(dist_moved))
	if remaining > 0:
		log_requested.emit("Rango restante: %d" % remaining)
		pending_move_range = remaining
		map_area.start_move_selection(remaining)
		end_move_button_visible_changed.emit(true)
		hand_refresh_requested.emit()
		ui_update_requested.emit()
	else:
		end_move_button_visible_changed.emit(false)
		clear_pending_move()
		if move_mode:
			move_mode_button_reset_requested.emit()
		hand_refresh_requested.emit()
		ui_update_requested.emit()

func _execute_push(direction_target: Vector2) -> void:
	var card: CardData = state.hand[pending_push_index]
	var idx := pending_push_index
	var push_from: Vector2 = map_area.enemy_pos

	state.player_energy -= card.cost

	var landing: Vector2 = map_area.calculate_push_landing(direction_target, float(card.throw_range))
	map_area.clear_push_selection()

	# 1. Animación de ataque del jugador
	map_area.play_player_anim("attack")
	await map_area.player_anim_finished
	map_area.play_player_anim("idle")

	# 2. El enemigo vuela
	map_area.push_enemy_to(landing)
	await map_area.enemy_reached_target

	# 3. Animación de daño del enemigo
	map_area.play_enemy_anim("damage")
	await map_area.enemy_anim_finished
	if state.enemy_hp > 0:
		map_area.play_enemy_anim("idle")

	state.discard_pile.append(state.hand[idx])
	state.hand.remove_at(idx)
	pending_push_index = -1
	pending_push_phase = 0
	pending_push_card  = null
	card_preview_hide_requested.emit()

	var fx: Dictionary = map_area.trigger_zone_effects_along(push_from, landing)
	if fx["wet"]:
		state.enemy_wet_turns = 3
		log_requested.emit("¡%s! El enemigo pasó por el charco. ¡Está mojado!" % card.name)
	if fx["trap_damage"] > 0:
		log_requested.emit("¡%s! El enemigo pasó por una trampa — %d de daño!" % [card.name, fx["trap_damage"]])
		await _deal_damage_to_enemy.call(fx["trap_damage"])
	if not fx["wet"] and fx["trap_damage"] == 0:
		log_requested.emit("%s: empujaste al enemigo." % card.name)

	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _execute_puddle(cell: Vector2) -> void:
	var card: CardData = state.hand[pending_puddle_index]
	var idx := pending_puddle_index
	state.player_energy -= card.cost
	map_area.clear_puddle_placement()
	map_area.place_puddle(cell, card.card_range)
	state.discard_pile.append(state.hand[idx])
	state.hand.remove_at(idx)
	pending_puddle_index = -1
	card_preview_hide_requested.emit()
	log_requested.emit("%s: charco colocado." % card.name)
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func _execute_jump_attack(landing_pos: Vector2) -> void:
	var card: CardData = state.hand[pending_jump_index]
	var idx := pending_jump_index

	state.player_energy -= card.cost

	var sep: Vector2 = landing_pos - map_area.enemy_pos
	if sep.length() < map_area.MIN_SEPARATION:
		landing_pos = map_area.enemy_pos + (sep.normalized() if sep.length() > 0.001 else Vector2(map_area.MIN_SEPARATION, 0.0)) * map_area.MIN_SEPARATION

	map_area.player_pos       = landing_pos
	map_area.player_elevation = map_area._elevation_at(landing_pos)
	map_area._update_actor_positions()

	var hit_enemy: bool = map_area.is_enemy_near_pos(landing_pos, 1.5)

	map_area.clear_rock_jump_selection()
	state.discard_pile.append(state.hand[idx])
	state.hand.remove_at(idx)
	_clear_pending_jump()
	card_preview_hide_requested.emit()

	if hit_enemy:
		log_requested.emit("¡%s! Caíste sobre el enemigo — %d de daño!" % [card.name, card.damage])
		await _deal_damage_to_enemy.call(card.damage)
	else:
		log_requested.emit("%s: aterrizaste en (%.1f, %.1f)." % [card.name, landing_pos.x, landing_pos.y])

	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _clear_pending_jump() -> void:
	pending_jump_index    = -1
	pending_jump_phase    = 0
	pending_jump_rock_pos = Vector2(-1.0, -1.0)
	pending_jump_card     = null

func _place_trap(cell: Vector2) -> void:
	var card: CardData = state.hand[pending_trap_index]
	var is_nearby := card.card_type == "trap_place"

	if is_nearby and map_area.movement_distance(map_area.player_pos, cell) > 8.0:
		log_requested.emit("Too far to place %s." % card.name)
		return

	if not is_nearby and card.throw_range > 0 and map_area.movement_distance(map_area.player_pos, cell) > float(card.throw_range):
		log_requested.emit("Too far to throw %s." % card.name)
		return

	if not map_area.has_line_of_sight(map_area.player_pos, cell):
		log_requested.emit("Obstacle in the way — can't place %s there." % card.name)
		return

	state.player_energy -= card.cost
	map_area.place_trap(cell, card.card_range, card.damage, card.name)
	log_requested.emit("Placed %s at (%.1f,%.1f)." % [card.name, cell.x, cell.y])
	state.discard_pile.append(state.hand[pending_trap_index])
	state.hand.remove_at(pending_trap_index)
	pending_trap_index = -1
	card_preview_hide_requested.emit()
	map_area.clear_trap_placement()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func _throw_grenade(target: Vector2) -> void:
	var card: CardData = state.hand[pending_grenade_index]

	if card.throw_range > 0 and map_area.movement_distance(map_area.player_pos, target) > float(card.throw_range):
		log_requested.emit("Too far to throw %s." % card.name)
		return

	if not map_area.has_line_of_sight(map_area.player_pos, target):
		log_requested.emit("Obstacle in the way — can't throw %s there." % card.name)
		return

	map_area.clear_trap_placement()
	var landing: Vector2 = map_area.calculate_grenade_landing(map_area.player_pos, target, card.bounce)
	map_area.show_grenade_preview(landing, card.card_range)

	state.player_energy -= card.cost
	if map_area.is_enemy_in_explosion(landing, card.card_range):
		log_requested.emit("%s lands at (%.1f,%.1f) — %d damage!" % [card.name, landing.x, landing.y, card.damage])
		await _deal_damage_to_enemy.call(card.damage)
	else:
		log_requested.emit("%s lands at (%.1f,%.1f) — miss!" % [card.name, landing.x, landing.y])

	state.discard_pile.append(state.hand[pending_grenade_index])
	state.hand.remove_at(pending_grenade_index)
	pending_grenade_index = -1

	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	card_preview_hide_requested.emit()
	map_area.clear_grenade_preview()
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _confirm_range_attack() -> void:
	if pending_attack_index < 0 or pending_attack_index >= state.hand.size():
		clear_pending_attack()
		return

	var card = state.hand[pending_attack_index]
	if not map_area.is_enemy_in_attack_range(pending_attack_range):
		log_requested.emit("%s: el enemigo está fuera de rango." % card.name)
		clear_pending_attack()
		return

	state.player_energy -= card.cost
	log_requested.emit("Played %s for %d damage." % [card.name, card.damage])
	var idx := pending_attack_index
	clear_pending_attack()
	card_preview_hide_requested.emit()
	await _deal_damage_to_enemy.call(card.damage)
	state.discard_pile.append(state.hand[idx])
	state.hand.remove_at(idx)
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _confirm_self_action() -> void:
	if pending_self_index < 0 or pending_self_index >= state.hand.size():
		pending_self_index = -1
		map_area.clear_self_highlight()
		return
	var card: CardData = state.hand[pending_self_index]
	state.player_block += card.block_amount
	state.player_energy -= card.cost
	log_requested.emit("Played %s. Block: %d" % [card.name, state.player_block])
	state.discard_pile.append(state.hand[pending_self_index])
	state.hand.remove_at(pending_self_index)
	pending_self_index = -1
	card_preview_hide_requested.emit()
	map_area.clear_self_highlight()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

# ── Clear pending ─────────────────────────────────────────────────────────────

func clear_pending_attack() -> void:
	pending_attack_section = ""
	pending_attack_index = -1
	pending_attack_range = 0
	map_area.clear_attack_selection()

func clear_pending_move() -> void:
	pending_move_section = ""
	pending_move_index = -1
	pending_move_range = 0
	pending_move_started = false
	end_move_button_visible_changed.emit(false)
	map_area.clear_path_preview()
	if map_area.has_method("clear_move_selection"):
		map_area.clear_move_selection()

func cancel_selection() -> void:
	if pending_move_started:
		_finish_movement()
		return
	if pending_attack_index >= 0:
		clear_pending_attack()
	if pending_trap_index >= 0:
		pending_trap_index = -1
		map_area.clear_trap_placement()
	if pending_grenade_index >= 0:
		pending_grenade_index = -1
		map_area.clear_trap_placement()
	if pending_self_index >= 0:
		pending_self_index = -1
		map_area.clear_self_highlight()
	if pending_push_index >= 0:
		map_area.clear_push_selection()
		pending_push_index = -1
		pending_push_phase = 0
		pending_push_card  = null
	if pending_puddle_index >= 0:
		map_area.clear_puddle_placement()
		pending_puddle_index = -1
	if pending_jump_index >= 0:
		map_area.clear_rock_jump_selection()
		_clear_pending_jump()
	if pending_move_index >= 0:
		clear_pending_move()
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func reset() -> void:
	card_preview_hide_requested.emit()
	clear_pending_move()
	clear_pending_attack()
	pending_grenade_index = -1
	pending_trap_index    = -1
	pending_self_index    = -1
	map_area.clear_grenade_preview()
	map_area.clear_trap_placement()
	map_area.clear_self_highlight()
	if pending_push_index >= 0:
		map_area.clear_push_selection()
	pending_push_index = -1
	pending_push_phase = 0
	pending_push_card  = null
	if pending_puddle_index >= 0:
		map_area.clear_puddle_placement()
	pending_puddle_index = -1
	if pending_jump_index >= 0:
		map_area.clear_rock_jump_selection()
	_clear_pending_jump()
	move_mode_button_reset_requested.emit()
	move_mode = false
