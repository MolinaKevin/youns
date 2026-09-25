class_name CombatPlayerActions
extends RefCounted

# Todas las distancias de las cartas y de este archivo están en casillas de la
# grilla (CombatGrid.CELL). Se pasan a unidades de mundo con _w() solo al hablar
# con el mapa.
const MOVE_MODE_RANGE     := 38   # "Mover" con cualquier mitad
const MELEE_RANGE         := 13   # alcance cuerpo a cuerpo (las cartas melee no traen rango)
const NEARBY_TRAP_RANGE   := 100  # trampa colocada "cerca"
const WET_MOVE_PENALTY    := 13
const GREASY_MOVE_PENALTY := 25
const BLINDED_RANGE       := 13   # rango máximo estando cegado

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
var pending_jump_card:     CardActionLine = null

var pending_push_index: int      = -1
var pending_push_phase: int      = 0
var pending_push_card:  CardActionLine = null

var pending_puddle_index:    int      = -1
var pending_overwatch_index: int      = -1
var pending_overwatch_card:  CardActionLine = null
var pending_overwatch_dir:   Vector2  = Vector2.ZERO

var pending_cell := Vector2(-1.0, -1.0)

signal log_requested(text: String)
signal hand_refresh_requested()
signal ui_update_requested()
signal card_preview_show_requested(card: CardActionLine)
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

## Casillas de la grilla → unidades de mundo del mapa.
static func _w(cells: int) -> float:
	return float(cells) * CombatGrid.CELL

func _move_penalty() -> int:
	return (WET_MOVE_PENALTY if state.player_wet_turns > 0 else 0) \
		+ (GREASY_MOVE_PENALTY if state.player_greasy_turns > 0 else 0)

# ── Card selection ────────────────────────────────────────────────────────────

func _on_card_selected(card: CardActionLine) -> void:
	if _has_pending_selection():
		cancel_selection()
	var index: int = state.turn_actions.find(card)
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
		pending_puddle_index >= 0 or
		pending_overwatch_index >= 0
	)

func _on_move_mode_toggled(pressed: bool) -> void:
	move_mode = pressed
	if not pressed:
		clear_pending_move()

func play_as_move(index: int) -> void:
	var card = state.turn_actions[index]
	if state.player_overwatch_active:
		state.player_overwatch_active = false
		map_area.clear_overwatch_zone()
		log_requested.emit("Vigilancia cancelada.")
	if state.player_entangled_turns > 0:
		log_requested.emit("¡Estás enredado! No podés moverte (%d turnos)." % state.player_entangled_turns)
		card_preview_hide_requested.emit()
		return
	if state.player_frozen_turns > 0:
		log_requested.emit("¡Estás congelado! No podés moverte (%d turnos)." % state.player_frozen_turns)
		card_preview_hide_requested.emit()
		return
	card_preview_show_requested.emit(card)
	var penalty := _move_penalty()
	var effective_range := maxi(1, MOVE_MODE_RANGE - penalty)
	if penalty > 0:
		log_requested.emit("Movimiento reducido a %d (penalización %d)." % [effective_range, penalty])
	pending_move_section = "hand"
	pending_move_index = index
	pending_move_range = effective_range
	map_area.start_move_selection(_w(effective_range))
	log_requested.emit("Move mode: choose a tile up to %d spaces away." % effective_range)

func play_card(index: int) -> void:
	var card = state.turn_actions[index]

	if state.player_overwatch_active and card.card_type != "overwatch":
		state.player_overwatch_active = false
		map_area.clear_overwatch_zone()
		log_requested.emit("Vigilancia cancelada.")
	card_preview_show_requested.emit(card)
	match card.card_type:
		"move":
			start_move_selection("hand", index, card.card_range, card.name)
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
		"overwatch":
			start_overwatch_selection(index, card)

# ── Selection starters ────────────────────────────────────────────────────────

func start_move_selection(section_name: String, index: int, move_range: int, card_name: String) -> void:
	if state.player_entangled_turns > 0:
		log_requested.emit("¡Estás enredado! No podés moverte (%d turnos)." % state.player_entangled_turns)
		card_preview_hide_requested.emit()
		return
	if state.player_frozen_turns > 0:
		log_requested.emit("¡Estás congelado! No podés moverte (%d turnos)." % state.player_frozen_turns)
		card_preview_hide_requested.emit()
		return
	var penalty := _move_penalty()
	var effective_range := maxi(1, move_range - penalty)
	if penalty > 0:
		log_requested.emit("Movimiento reducido a %d (penalización %d)." % [effective_range, penalty])
	pending_move_section = section_name
	pending_move_index = index
	pending_move_range = effective_range
	map_area.start_move_selection(_w(effective_range))
	log_requested.emit("Selected %s. Choose a tile up to %d spaces away." % [card_name, effective_range])

func start_range_attack_selection(index: int, card: CardActionLine, range_override: int = 0) -> void:
	pending_attack_section = "hand"
	pending_attack_index   = index
	var base_range := range_override if range_override > 0 else card.card_range
	if state.player_blinded_turns > 0:
		base_range = mini(base_range, BLINDED_RANGE)
		log_requested.emit("¡Estás cegado! Rango reducido a 1.")
	pending_attack_range = base_range
	map_area.start_attack_selection(_w(pending_attack_range))

func start_grenade_selection(index: int, card: CardActionLine) -> void:
	pending_grenade_index = index
	map_area.start_trap_placement(_w(card.throw_range))
	log_requested.emit("Selected %s. Choose a tile up to %d spaces away (bounce: %.1f)." % [card.name, card.throw_range, card.bounce])

func start_trap_selection(index: int, card: CardActionLine, nearby: bool) -> void:
	pending_trap_index = index
	if nearby:
		map_area.start_trap_placement(_w(NEARBY_TRAP_RANGE), _w(card.card_range))
		log_requested.emit("Place %s nearby (range %d)." % [card.name, NEARBY_TRAP_RANGE])
	else:
		map_area.start_trap_placement(_w(card.throw_range), _w(card.card_range))
		log_requested.emit("Throw %s — choose a tile up to %d spaces away." % [card.name, card.throw_range])

func start_self_selection(index: int, card: CardActionLine) -> void:
	pending_self_index = index
	map_area.start_self_highlight()

func start_push_selection(index: int, card: CardActionLine) -> void:
	pending_push_index = index
	pending_push_phase = 0
	pending_push_card  = card
	map_area.start_push_enemy_selection(_w(card.card_range))
	log_requested.emit("Seleccioná al enemigo para agarrarlo.")

func start_overwatch_selection(index: int, card: CardActionLine) -> void:
	pending_overwatch_index = index
	pending_overwatch_card  = card
	map_area.start_overwatch_selection(_w(card.card_range), 10.0)
	log_requested.emit("Apuntá el cono hacia donde querés vigilar.")

func start_puddle_selection(index: int, card: CardActionLine) -> void:
	pending_puddle_index = index
	map_area.start_puddle_placement(_w(card.throw_range), card.puddle_effect, _w(card.card_range))
	log_requested.emit("Elegí dónde lanzar el charco (rango %d)." % card.throw_range)

func start_rock_jump_selection(index: int, card: CardActionLine) -> void:
	var rocks: Array[Dictionary] = map_area.get_rocks_in_range(map_area.player_pos, _w(card.card_range))
	if rocks.is_empty():
		log_requested.emit("%s: no hay piedras al alcance." % card.name)
		card_preview_hide_requested.emit()
		return
	pending_jump_index = index
	pending_jump_phase = 0
	pending_jump_card  = card
	map_area.start_rock_jump_selection(_w(card.card_range))
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
		pending_puddle_index >= 0 or
		pending_overwatch_index >= 0
	)
	if not has_pending:
		return

	if pending_overwatch_index >= 0:
		var dir: Vector2 = pos - map_area.player_pos
		if dir.length() > 0.2:
			pending_overwatch_dir = dir.normalized()
			confirm_popup_show_requested.emit(false)
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
			if not map_area.is_enemy_in_attack_range(_w(pending_push_card.card_range)):
				log_requested.emit("El enemigo está demasiado lejos para agarrarlo.")
				return
			if not map_area.is_click_on_enemy(pos):
				return
			pending_push_phase = 1
			map_area.start_push_cone(_w(pending_push_card.throw_range))
			log_requested.emit("Elegí hacia dónde empujar al enemigo.")
			return
		else:
			if not map_area.is_pos_in_push_cone(pos, _w(pending_push_card.throw_range)):
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
			map_area.start_jump_landing_selection(pending_jump_rock_pos, _w(pending_jump_card.throw_range))
			log_requested.emit("Piedra en (%.1f, %.1f). Elegí dónde aterrizar." % [pending_jump_rock_pos.x, pending_jump_rock_pos.y])
			return
		else:
			if pending_jump_rock_pos.distance_to(pos) > _w(pending_jump_card.throw_range):
				return
			if map_area._tile_in_obstacle(pos, 0):
				return
			pending_cell = pos
			confirm_popup_show_requested.emit(false)
			return

	pending_cell = pos
	var is_move_pending := pending_move_index >= 0 or pending_move_started
	if is_move_pending:
		# Cada rechazo avisa en el log: antes el clic "no hacía nada" sin explicación.
		var player: Vector2 = map_area.get("player_pos")
		match map_area.plan_player_move(pos):
			"range":
				log_requested.emit("Ese lugar está fuera de tu alcance de movimiento (%d)." % pending_move_range)
				return
			"blocked":
				log_requested.emit("No entrás en ese lugar: hay un obstáculo o el enemigo.")
				return
			"no_path":
				log_requested.emit("No hay camino hasta ahí dentro de tu alcance.")
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

	if pending_overwatch_index >= 0:
		_execute_overwatch(pending_overwatch_dir)
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

	var zone_fx: Dictionary = map_area.get_puddle_effects_along(move_from, map_area.player_pos)
	if zone_fx.get("wet", false):
		state.player_wet_turns = 3
		log_requested.emit("¡Pisaste el charco! Estás mojado por 3 turnos.")
	if zone_fx.get("fire", false) and state.player_burning_turns == 0:
		state.player_burning_turns = 3
		log_requested.emit("¡Pisaste fuego! Estás en llamas por 3 turnos.")
	if zone_fx.get("grease", false) and state.player_greasy_turns == 0:
		state.player_greasy_turns = 3
		log_requested.emit("¡Pisaste grasa! Movimiento reducido por 3 turnos.")
	if zone_fx.get("vine", false) and state.player_entangled_turns == 0:
		state.player_entangled_turns = 2
		log_requested.emit("¡Las enredaderas te atraparon! No podés moverte por 2 turnos.")
	if zone_fx.get("blood", false) and state.player_bleeding_turns == 0:
		state.player_bleeding_turns = 4
		log_requested.emit("¡Pisaste sangre! Estás sangrando por 4 turnos.")
	if zone_fx.get("poison", false) and state.player_poison_stacks == 0:
		state.player_poison_stacks = 3
		log_requested.emit("¡Pisaste veneno! Estás envenenado (3→2→1).")
	if zone_fx.get("sand", false) and state.player_blinded_turns == 0:
		state.player_blinded_turns = 2
		log_requested.emit("¡Arena en los ojos! Rango de ataque reducido a 1 por 2 turnos.")
	if zone_fx.get("ice", false) and state.player_frozen_turns == 0:
		state.player_frozen_turns = 2
		log_requested.emit("¡Pisaste hielo! Estás congelado por 2 turnos.")
	if zone_fx.get("bloody_ice", false):
		if state.player_frozen_turns == 0:
			state.player_frozen_turns = 2
		if state.player_bleeding_turns == 0:
			state.player_bleeding_turns = 3
		log_requested.emit("¡Pisaste hielo sangriento! Congelado y sangrando.")
	if zone_fx.get("dark_smoke", false) and state.player_blinded_turns == 0:
		state.player_blinded_turns = 3
		log_requested.emit("¡Humo oscuro! No podés ver bien por 3 turnos.")

	var trap_dmg: int = map_area.check_and_trigger_traps_along_path(map_area.player_pos, cell)
	if trap_dmg > 0:
		_deal_damage_to_player.call(trap_dmg)
		log_requested.emit("Pisaste una trampa en el camino! %d daño." % trap_dmg)
		if _check_combat_end.call():
			return

	if not pending_move_started:
		var card = state.turn_actions[pending_move_index]
		log_requested.emit("Played %s." % card.name)
		state.turn_actions.remove_at(pending_move_index)
		pending_move_index = -1
		pending_move_started = true

	var remaining := maxi(0, pending_move_range - roundi(dist_moved / CombatGrid.CELL))
	if remaining > 0:
		log_requested.emit("Rango restante: %d" % remaining)
		pending_move_range = remaining
		map_area.start_move_selection(_w(remaining))
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
	var card: CardActionLine = state.turn_actions[pending_push_index]
	var idx := pending_push_index
	var push_from: Vector2 = map_area.enemy_pos

	var landing: Vector2 = map_area.calculate_push_landing(direction_target, _w(card.throw_range))
	map_area.clear_push_selection()

	# Se gasta antes de las animaciones (ver _confirm_range_attack).
	state.turn_actions.remove_at(idx)
	pending_push_index = -1
	pending_push_phase = 0
	pending_push_card  = null
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()

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

	var fx: Dictionary = map_area.trigger_zone_effects_along(push_from, landing)
	var any_zone := false
	if fx.get("wet", false):
		state.enemy_wet_turns = 3
		log_requested.emit("El enemigo pasó por agua. ¡Está mojado!")
		any_zone = true
	if fx.get("fire", false) and state.enemy_burning_turns == 0:
		state.enemy_burning_turns = 3
		log_requested.emit("El enemigo pasó por el fuego. ¡Está en llamas!")
		any_zone = true
	if fx.get("grease", false) and state.enemy_greasy_turns == 0:
		state.enemy_greasy_turns = 3
		log_requested.emit("El enemigo pasó por grasa. ¡Movimiento reducido!")
		any_zone = true
	if fx.get("vine", false) and state.enemy_entangled_turns == 0:
		state.enemy_entangled_turns = 2
		log_requested.emit("¡El enemigo quedó enredado por 2 turnos!")
		any_zone = true
	if fx.get("blood", false) and state.enemy_bleeding_turns == 0:
		state.enemy_bleeding_turns = 4
		log_requested.emit("El enemigo pasó por sangre. ¡Está sangrando!")
		any_zone = true
	if fx.get("poison", false) and state.enemy_poison_stacks == 0:
		state.enemy_poison_stacks = 3
		log_requested.emit("El enemigo pasó por veneno. ¡Está envenenado!")
		any_zone = true
	if fx.get("sand", false) and state.enemy_blinded_turns == 0:
		state.enemy_blinded_turns = 2
		log_requested.emit("¡El enemigo fue cegado por 2 turnos!")
		any_zone = true
	if fx.get("trap_damage", 0) > 0:
		log_requested.emit("¡%s! El enemigo pasó por una trampa — %d de daño!" % [card.name, fx["trap_damage"]])
		await _deal_damage_to_enemy.call(fx["trap_damage"])
		any_zone = true
	if not any_zone:
		log_requested.emit("%s: empujaste al enemigo." % card.name)

	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _execute_overwatch(dir: Vector2) -> void:
	var card: CardActionLine = state.turn_actions[pending_overwatch_index]
	var idx := pending_overwatch_index
	map_area.clear_overwatch_selection()
	map_area.place_overwatch(map_area.player_pos, dir, _w(card.card_range), 10.0)
	state.player_overwatch_active     = true
	state.player_overwatch_origin     = map_area.player_pos
	state.player_overwatch_dir        = dir
	state.player_overwatch_range      = _w(card.card_range)
	state.player_overwatch_half_angle = 10.0
	state.player_overwatch_damage     = card.damage
	state.turn_actions.remove_at(idx)
	pending_overwatch_index = -1
	pending_overwatch_card  = null
	card_preview_hide_requested.emit()
	log_requested.emit("%s: zona de vigilancia activa. Si el enemigo entra, se dispara." % card.name)
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func _execute_puddle(cell: Vector2) -> void:
	var card: CardActionLine = state.turn_actions[pending_puddle_index]
	var idx := pending_puddle_index
	map_area.clear_puddle_placement()
	map_area.place_puddle(cell, _w(card.card_range), card.puddle_effect)
	state.turn_actions.remove_at(idx)
	pending_puddle_index = -1
	card_preview_hide_requested.emit()
	log_requested.emit("%s: colocado." % card.name)
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func _execute_jump_attack(landing_pos: Vector2) -> void:
	var card: CardActionLine = state.turn_actions[pending_jump_index]
	var idx := pending_jump_index

	var sep: Vector2 = landing_pos - map_area.enemy_pos
	if sep.length() < map_area.MIN_SEPARATION:
		landing_pos = map_area.enemy_pos + (sep.normalized() if sep.length() > 0.001 else Vector2(map_area.MIN_SEPARATION, 0.0)) * map_area.MIN_SEPARATION

	map_area.player_pos       = landing_pos
	map_area.player_elevation = map_area._elevation_at(landing_pos)
	map_area._update_actor_positions()

	var hit_enemy: bool = map_area.is_enemy_near_pos(landing_pos, 1.5)

	map_area.clear_rock_jump_selection()
	state.turn_actions.remove_at(idx)
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
	var card: CardActionLine = state.turn_actions[pending_trap_index]
	var is_nearby := card.card_type == "trap_place"

	if is_nearby and map_area.movement_distance(map_area.player_pos, cell) > _w(NEARBY_TRAP_RANGE):
		log_requested.emit("Too far to place %s." % card.name)
		return

	if not is_nearby and card.throw_range > 0 and map_area.movement_distance(map_area.player_pos, cell) > _w(card.throw_range):
		log_requested.emit("Too far to throw %s." % card.name)
		return

	if not map_area.has_line_of_sight(map_area.player_pos, cell):
		log_requested.emit("Obstacle in the way — can't place %s there." % card.name)
		return
	map_area.place_trap(cell, _w(card.card_range), card.damage, card.name)
	log_requested.emit("Placed %s at (%.1f,%.1f)." % [card.name, cell.x, cell.y])
	state.turn_actions.remove_at(pending_trap_index)
	pending_trap_index = -1
	card_preview_hide_requested.emit()
	map_area.clear_trap_placement()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func _throw_grenade(target: Vector2) -> void:
	var card: CardActionLine = state.turn_actions[pending_grenade_index]

	if card.throw_range > 0 and map_area.movement_distance(map_area.player_pos, target) > _w(card.throw_range):
		log_requested.emit("Too far to throw %s." % card.name)
		return

	if not map_area.has_line_of_sight(map_area.player_pos, target):
		log_requested.emit("Obstacle in the way — can't throw %s there." % card.name)
		return

	map_area.clear_trap_placement()
	var landing: Vector2 = map_area.calculate_grenade_landing(map_area.player_pos, target, card.bounce)
	map_area.show_grenade_preview(landing, _w(card.card_range))
	# Se gasta antes de las animaciones (ver _confirm_range_attack).
	state.turn_actions.remove_at(pending_grenade_index)
	pending_grenade_index = -1
	hand_refresh_requested.emit()
	if map_area.is_enemy_in_explosion(landing, _w(card.card_range)):
		log_requested.emit("%s lands at (%.1f,%.1f) — %d damage!" % [card.name, landing.x, landing.y, card.damage])
		await _deal_damage_to_enemy.call(card.damage)
	else:
		log_requested.emit("%s lands at (%.1f,%.1f) — miss!" % [card.name, landing.x, landing.y])

	await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout
	card_preview_hide_requested.emit()
	map_area.clear_grenade_preview()
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _confirm_range_attack() -> void:
	if pending_attack_index < 0 or pending_attack_index >= state.turn_actions.size():
		clear_pending_attack()
		return

	var card = state.turn_actions[pending_attack_index]
	if not map_area.is_enemy_in_attack_range(_w(pending_attack_range)):
		log_requested.emit("%s: el enemigo está fuera de rango." % card.name)
		clear_pending_attack()
		return
	log_requested.emit("Played %s for %d damage." % [card.name, card.damage])
	# La acción se gasta antes de la animación: durante el await el jugador puede
	# elegir otra mitad o terminar el turno y state.turn_actions cambia.
	state.turn_actions.remove_at(pending_attack_index)
	clear_pending_attack()
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()
	await _deal_damage_to_enemy.call(card.damage)
	ui_update_requested.emit()
	_check_combat_end.call()

func _confirm_self_action() -> void:
	if pending_self_index < 0 or pending_self_index >= state.turn_actions.size():
		pending_self_index = -1
		map_area.clear_self_highlight()
		return
	var card: CardActionLine = state.turn_actions[pending_self_index]
	state.player_block += card.block_amount
	log_requested.emit("Played %s. Block: %d" % [card.name, state.player_block])
	state.turn_actions.remove_at(pending_self_index)
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
	if pending_overwatch_index >= 0:
		map_area.clear_overwatch_selection()
		pending_overwatch_index = -1
		pending_overwatch_card  = null
		pending_overwatch_dir   = Vector2.ZERO
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
	if pending_overwatch_index >= 0:
		map_area.clear_overwatch_selection()
	pending_overwatch_index = -1
	pending_overwatch_card  = null
	pending_overwatch_dir   = Vector2.ZERO
	if pending_jump_index >= 0:
		map_area.clear_rock_jump_selection()
	_clear_pending_jump()
	move_mode_button_reset_requested.emit()
	move_mode = false
