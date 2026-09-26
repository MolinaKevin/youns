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

## Empuje, tirón y ancla comparten la selección: el tipo de pending_push_card
## decide adónde va el enemigo.
var pending_push_index: int      = -1
var pending_push_phase: int      = 0
var pending_push_card:  CardActionLine = null

## Módulos: romper ("break"), golpear ("module_push"), crear ("build"),
## lanzar ("module_throw") y derrumbar sobre el enemigo ("collapse").
## Golpear y lanzar tienen dos pasos: elegir el módulo (fase 0) y después la
## dirección o el punto de caída (fase 1).
var pending_module_index: int = -1
var pending_module_phase: int = 0
var pending_module_card:  CardActionLine = null
var pending_module_target: Dictionary = {}

## Hechizos a un punto, una dirección o el enemigo (ver _on_spell_click).
## Nova, curar y encantar arma van sobre uno mismo (start_self_selection).
var pending_spell_index: int = -1
var pending_spell_card:  CardActionLine = null
var pending_spell_dir:   Vector2 = Vector2.ZERO
## Traslado de charco: el charco elegido en el primer paso.
var pending_spell_puddle: Dictionary = {}
## Trepar árbol: el árbol elegido en el primer paso (usa el mismo flujo).
var pending_spell_tree: Dictionary = {}

## Árboles: daño al caerse de uno (talado o en llamas) y al tronco que le cae
## encima al enemigo.
const TREE_FALL_DAMAGE := 40
const TREE_CRUSH_DAMAGE := 60
## Turnos base de llamas al caerse de un árbol que se prendió fuego.
const TREE_FIRE_BURN_TURNS := 3
## Raíces cerca de un árbol: el enemigo queda enredado un turno más.
const TREE_ROOT_REACH := 1.5
const TREE_ROOT_BONUS_TURNS := 1

## Líneas que no se pueden usar arriba de un árbol (mueven al jugador).
const TREE_BLOCKED_LINES := ["move", "blink", "rock_jump", "tree_climb"]


## Qué charcos cambia cada hechizo elemental (element_bolt, según puddle_effect).
const ELEMENT_CONVERSIONS := {"fire": ["grease", "vine"], "ice": ["wet"]}
## Ancho (medio ángulo) de los hechizos en línea y en cono.
const BOLT_HALF_ANGLE := 4.0
const CONE_HALF_ANGLE := 30.0
## Turnos base que congela Escarcha a un enemigo mojado.
const FREEZE_TURNS := 2

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
		pending_module_index >= 0 or
		pending_spell_index >= 0 or
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
	if state.player_in_tree and card.card_type in TREE_BLOCKED_LINES:
		log_requested.emit("Estás arriba del árbol: no te podés mover hasta caer.")
		card_preview_hide_requested.emit()
		return
	match card.card_type:
		"move":
			start_move_selection("hand", index, card.card_range, card.name)
		"melee_attack":
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
		"block", "ward", "mp_restore", "counter", "nova", "heal", "enchant":
			start_self_selection(index, card)
		"element_bolt", "chain_bolt", "delayed_area", "cone_blast", "curse", "blink", "puddle_hop", "tree_climb":
			_start_spell_selection(index, card)
		"rock_jump":
			start_rock_jump_selection(index, card)
		"push", "pull", "anchor":
			start_push_selection(index, card)
		"break", "module_push", "build", "module_throw", "collapse":
			pending_module_index = index
			pending_module_phase = 0
			pending_module_card = card
			if card.card_type == "collapse":
				map_area.start_collapse_selection(_w(card.card_range))
			else:
				map_area.start_module_selection(_w(card.card_range))
			match card.card_type:
				"break": log_requested.emit("Elegí el módulo que querés romper.")
				"module_push": log_requested.emit("Elegí el módulo que querés golpear.")
				"build": log_requested.emit("Elegí dónde levantar el muro.")
				"module_throw": log_requested.emit("Elegí el módulo que querés levantar.")
				"collapse": log_requested.emit("Elegí al enemigo: los módulos pegados a él se le caen encima.")
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
	if card.card_type == "anchor":
		map_area.start_anchor_selection(_w(card.card_range))
		log_requested.emit("Elegí dónde clavar el ancla: el enemigo va a ser arrastrado hacia ahí.")
		return
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
		pending_module_index >= 0 or
		pending_spell_index >= 0 or
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

	if pending_module_index >= 0:
		_on_module_click(pos)
		return

	if pending_spell_index >= 0:
		_on_spell_click(pos)
		return

	if pending_push_index >= 0 and pending_push_card.card_type == "anchor":
		if map_area.movement_distance(map_area.player_pos, pos) > _w(pending_push_card.card_range):
			log_requested.emit("Demasiado lejos para clavar el ancla.")
			return
		if not map_area.has_line_of_sight(map_area.player_pos, pos):
			log_requested.emit("Hay algo en el medio: no llegás a clavar el ancla ahí.")
			return
		pending_cell = pos
		confirm_popup_show_requested.emit(false)
		return

	if pending_push_index >= 0:
		if pending_push_phase == 0:
			if not map_area.is_enemy_in_attack_range(_w(pending_push_card.card_range)):
				log_requested.emit("El enemigo está demasiado lejos para agarrarlo.")
				return
			if not map_area.is_click_on_enemy(pos):
				return
			if pending_push_card.card_type == "pull":
				pending_cell = map_area.player_pos
				confirm_popup_show_requested.emit(false)
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

	if pending_module_index >= 0:
		_execute_module_action(cell)
		return

	if pending_spell_index >= 0:
		_execute_spell(cell)
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

	apply_player_zone_effects(move_from, map_area.player_pos)

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

	var landing: Vector2
	match card.card_type:
		"pull":
			landing = map_area.calculate_drag_landing(map_area.player_pos, _w(card.throw_range))
		"anchor":
			landing = map_area.calculate_drag_landing(direction_target, _w(card.throw_range))
		_:
			landing = map_area.calculate_push_landing(direction_target, _w(card.throw_range))
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

	var any_zone: bool = await _apply_enemy_forced_move(card.name, push_from, landing)
	if not any_zone:
		match card.card_type:
			"pull": log_requested.emit("%s: acercaste al enemigo." % card.name)
			"anchor": log_requested.emit("%s: el ancla arrastró al enemigo." % card.name)
			_: log_requested.emit("%s: empujaste al enemigo." % card.name)

	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _on_module_click(pos: Vector2) -> void:
	var card := pending_module_card
	if card.card_type == "build":
		if map_area.movement_distance(map_area.player_pos, pos) > _w(card.card_range):
			log_requested.emit("Demasiado lejos para levantar el muro ahí.")
			return
		pending_cell = pos
		confirm_popup_show_requested.emit(false)
		return
	if card.card_type == "collapse":
		if not map_area.is_click_on_enemy(pos):
			return
		if not map_area.is_enemy_in_attack_range(_w(card.card_range)):
			log_requested.emit("El enemigo está demasiado lejos.")
			return
		pending_cell = pos
		confirm_popup_show_requested.emit(false)
		return
	if pending_module_phase == 1 and card.card_type == "module_throw":
		# Lanzar: elegir dónde cae.
		if map_area.movement_distance(map_area.player_pos, pos) > _w(card.throw_range):
			log_requested.emit("No llegás a tirarlo tan lejos.")
			return
		pending_cell = pos
		confirm_popup_show_requested.emit(false)
		return
	if pending_module_phase == 1:
		# Golpe: elegir la dirección dentro del cono.
		if not map_area.is_pos_in_module_cone(pending_module_target["pos"], pos, _w(card.throw_range)):
			return
		pending_cell = pos
		confirm_popup_show_requested.emit(false)
		return
	var obs: Dictionary = map_area.get_module_at(pos)
	if obs.is_empty() and card.card_type == "break":
		obs = map_area.get_tree_at(pos)  # romper también tala árboles
	if obs.is_empty():
		return
	if map_area.obstacle_gap(obs) > _w(card.card_range):
		log_requested.emit("Demasiado lejos para alcanzar eso.")
		return
	pending_module_target = obs
	if card.card_type == "module_throw":
		pending_module_phase = 1
		map_area.start_module_throw_target(_w(card.throw_range))
		log_requested.emit("Elegí dónde tirarlo.")
		return
	if card.card_type == "module_push":
		pending_module_phase = 1
		map_area.start_module_push_cone(obs["pos"], _w(card.throw_range))
		log_requested.emit("Elegí hacia dónde mandar el módulo.")
		return
	pending_cell = pos
	confirm_popup_show_requested.emit(false)

func _execute_module_action(cell: Vector2) -> void:
	var card: CardActionLine = state.turn_actions[pending_module_index]
	var obs := pending_module_target
	state.turn_actions.remove_at(pending_module_index)
	_clear_pending_module()
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()
	map_area.play_player_anim("attack")
	await map_area.player_anim_finished
	map_area.play_player_anim("idle")
	var count := maxi(1, card.module_count)
	match card.card_type:
		"break":
			if obs.get("type", "") == "tree":
				await _fell_tree(card, obs)
			else:
				var broken: int = map_area.break_modules(obs, count)
				log_requested.emit("%s: rompiste %d módulo(s)." % [card.name, broken])
		"build":
			var built: int = map_area.build_modules(cell, count)
			log_requested.emit("%s: levantaste %d módulo(s)." % [card.name, built])
		"module_push":
			var result: Dictionary = map_area.slide_module(obs, cell - obs["pos"], _w(card.throw_range))
			match result["hit"]:
				"enemy":
					log_requested.emit("¡%s! El módulo le pegó al enemigo — %d de daño." % [card.name, card.damage])
					await _deal_damage_to_enemy.call(card.damage, true, card.damage_type)
				"player":
					log_requested.emit("¡%s! El módulo te pegó a vos — %d de daño." % [card.name, card.damage])
					await _deal_damage_to_player.call(card.damage, true, card.damage_type)
				_:
					if not result.get("tree", {}).is_empty():
						log_requested.emit("%s: el módulo se estrella contra un árbol." % card.name)
					else:
						log_requested.emit("%s: mandaste el módulo a volar." % card.name)
		"module_throw":
			var hits: Dictionary = map_area.throw_module(obs, cell)
			if hits["enemy"]:
				log_requested.emit("¡%s! El módulo cayó sobre el enemigo — %d de daño." % [card.name, card.damage])
				await _deal_damage_to_enemy.call(card.damage, true, card.damage_type)
			if hits["player"]:
				log_requested.emit("¡%s! El módulo te cayó encima — %d de daño." % [card.name, card.damage])
				await _deal_damage_to_player.call(card.damage, true, card.damage_type)
			if not hits["enemy"] and not hits["player"]:
				log_requested.emit("%s: el módulo se hizo pedazos contra el suelo." % card.name)
		"collapse":
			var fallen: int = map_area.collapse_modules_on_enemy()
			if fallen == 0:
				log_requested.emit("%s: no hay módulos pegados al enemigo." % card.name)
			else:
				var total := card.damage * fallen
				log_requested.emit("¡%s! Se le cayeron %d módulo(s) encima — %d de daño." % [card.name, fallen, total])
				await _deal_damage_to_enemy.call(total, true, card.damage_type)
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

## Los charcos que pisó el jugador entre `from` y `to` le aplican sus estados
## (al moverse, o al caer de un árbol: from == to).
func apply_player_zone_effects(from: Vector2, to: Vector2) -> void:
	var zone_fx: Dictionary = map_area.get_puddle_effects_along(from, to)
	var zone_dmg: Dictionary = map_area.get_puddle_damage_along(from, to)
	if zone_fx.get("wet", false):
		state.player_wet_turns = state.status_turns(3, true)
		log_requested.emit("¡Pisaste el charco! Estás mojado por %d turnos." % state.player_wet_turns)
	if zone_fx.get("fire", false) and state.player_burning_turns == 0:
		state.player_burning_turns = state.status_turns(3, true)
		state.player_burn_damage = zone_dmg.get("fire", CombatState.BURN_DAMAGE)
		log_requested.emit("¡Pisaste fuego! Estás en llamas por %d turnos." % state.player_burning_turns)
	if zone_fx.get("grease", false) and state.player_greasy_turns == 0:
		state.player_greasy_turns = state.status_turns(3, true)
		log_requested.emit("¡Pisaste grasa! Movimiento reducido por %d turnos." % state.player_greasy_turns)
	if zone_fx.get("vine", false) and state.player_entangled_turns == 0:
		state.player_entangled_turns = state.status_turns(2, true)
		log_requested.emit("¡Las enredaderas te atraparon! No podés moverte por %d turnos." % state.player_entangled_turns)
	if zone_fx.get("blood", false) and state.player_bleeding_turns == 0:
		state.player_bleeding_turns = state.status_turns(4, true)
		state.player_bleed_damage = zone_dmg.get("blood", CombatState.BLEED_DAMAGE)
		log_requested.emit("¡Pisaste sangre! Estás sangrando por %d turnos." % state.player_bleeding_turns)
	if zone_fx.get("poison", false) and state.player_poison_stacks == 0:
		state.player_poison_stacks = state.status_turns(3, true)
		state.player_poison_damage = zone_dmg.get("poison", CombatState.POISON_DAMAGE_PER_STACK)
		log_requested.emit("¡Pisaste veneno! Estás envenenado (%d acumulaciones)." % state.player_poison_stacks)
	if zone_fx.get("sand", false) and state.player_blinded_turns == 0:
		state.player_blinded_turns = state.status_turns(2, true)
		log_requested.emit("¡Arena en los ojos! Rango de ataque reducido a 1 por %d turnos." % state.player_blinded_turns)
	if zone_fx.get("ice", false) and state.player_frozen_turns == 0:
		state.player_frozen_turns = state.status_turns(2, true)
		log_requested.emit("¡Pisaste hielo! Estás congelado por %d turnos." % state.player_frozen_turns)
	if zone_fx.get("bloody_ice", false):
		if state.player_frozen_turns == 0:
			state.player_frozen_turns = state.status_turns(2, true)
		if state.player_bleeding_turns == 0:
			state.player_bleeding_turns = state.status_turns(3, true)
			state.player_bleed_damage = zone_dmg.get("bloody_ice", CombatState.BLEED_DAMAGE)
		log_requested.emit("¡Pisaste hielo sangriento! Congelado y sangrando.")
	if zone_fx.get("dark_smoke", false) and state.player_blinded_turns == 0:
		state.player_blinded_turns = state.status_turns(3, true)
		log_requested.emit("¡Humo oscuro! No podés ver bien por %d turnos." % state.player_blinded_turns)

## Talar: el árbol cae alejándose del jugador y queda un tronco tirado.
func _fell_tree(card: CardActionLine, tree: Dictionary) -> void:
	var result: Dictionary = map_area.fell_tree(tree, tree["pos"] - map_area.player_pos)
	log_requested.emit("%s: el árbol cae y queda un tronco tirado." % card.name)
	if result["enemy_hit"]:
		log_requested.emit("¡El árbol le cae encima al enemigo — %d de daño!" % TREE_CRUSH_DAMAGE)
		await _deal_damage_to_enemy.call(TREE_CRUSH_DAMAGE, true, CombatState.FISICO)

## El jugador se cae del árbol (lo talaron o se prendió fuego): daño de caída
## y, si ardía, queda en llamas. map_area ya lo bajó al pie del árbol.
func player_falls_from_tree(burning: bool) -> void:
	if not state.player_in_tree:
		return
	state.player_in_tree = false
	log_requested.emit("¡Te caés del árbol — %d de daño!" % TREE_FALL_DAMAGE)
	await _deal_damage_to_player.call(TREE_FALL_DAMAGE, true, CombatState.FISICO)
	if burning and state.player_hp > 0:
		var turns: int = state.set_player_status("burn", TREE_FIRE_BURN_TURNS)
		log_requested.emit("¡El árbol ardía: quedás en llamas por %d turnos!" % turns)
	if state.player_hp > 0:
		apply_player_zone_effects(map_area.player_pos, map_area.player_pos)
	ui_update_requested.emit()
	_check_combat_end.call()

func _clear_pending_module() -> void:
	if pending_module_index >= 0:
		map_area.clear_module_selection()
	pending_module_index = -1
	pending_module_phase = 0
	pending_module_card = null
	pending_module_target = {}

## El enemigo fue movido a la fuerza (empuje, tirón, ancla, nova): se le
## aplican los charcos y trampas que cruzó. Devuelve si pasó por alguno.
func _apply_enemy_forced_move(card_name: String, from: Vector2, landing: Vector2) -> bool:
	var fx: Dictionary = map_area.trigger_zone_effects_along(from, landing)
	var zone_dmg: Dictionary = map_area.get_puddle_damage_along(from, landing)
	var any_zone := false
	if fx.get("wet", false):
		state.enemy_wet_turns = state.status_turns(3, false)
		log_requested.emit("El enemigo pasó por agua. ¡Está mojado!")
		any_zone = true
	if fx.get("fire", false) and state.enemy_burning_turns == 0:
		state.enemy_burning_turns = state.status_turns(3, false)
		state.enemy_burn_damage = zone_dmg.get("fire", CombatState.BURN_DAMAGE)
		log_requested.emit("El enemigo pasó por el fuego. ¡Está en llamas!")
		any_zone = true
	if fx.get("grease", false) and state.enemy_greasy_turns == 0:
		state.enemy_greasy_turns = state.status_turns(3, false)
		log_requested.emit("El enemigo pasó por grasa. ¡Movimiento reducido!")
		any_zone = true
	if fx.get("vine", false) and state.enemy_entangled_turns == 0:
		state.enemy_entangled_turns = state.status_turns(2, false)
		log_requested.emit("¡El enemigo quedó enredado por %d turnos!" % state.enemy_entangled_turns)
		any_zone = true
	if fx.get("blood", false) and state.enemy_bleeding_turns == 0:
		state.enemy_bleeding_turns = state.status_turns(4, false)
		state.enemy_bleed_damage = zone_dmg.get("blood", CombatState.BLEED_DAMAGE)
		log_requested.emit("El enemigo pasó por sangre. ¡Está sangrando!")
		any_zone = true
	if fx.get("poison", false) and state.enemy_poison_stacks == 0:
		state.enemy_poison_stacks = state.status_turns(3, false)
		state.enemy_poison_damage = zone_dmg.get("poison", CombatState.POISON_DAMAGE_PER_STACK)
		log_requested.emit("El enemigo pasó por veneno. ¡Está envenenado!")
		any_zone = true
	if fx.get("sand", false) and state.enemy_blinded_turns == 0:
		state.enemy_blinded_turns = state.status_turns(2, false)
		log_requested.emit("¡El enemigo fue cegado por %d turnos!" % state.enemy_blinded_turns)
		any_zone = true
	if fx.get("trap_damage", 0) > 0:
		log_requested.emit("¡%s! El enemigo pasó por una trampa — %d de daño!" % [card_name, fx["trap_damage"]])
		await _deal_damage_to_enemy.call(fx["trap_damage"])
		any_zone = true
	return any_zone

# ── Hechizos ──────────────────────────────────────────────────────────────────

func _start_spell_selection(index: int, card: CardActionLine) -> void:
	pending_spell_index = index
	pending_spell_card = card
	pending_spell_dir = Vector2.ZERO
	match card.card_type:
		"chain_bolt":
			map_area.start_overwatch_selection(_w(card.throw_range), BOLT_HALF_ANGLE)
			log_requested.emit("Elegí hacia dónde tirar el rayo.")
		"cone_blast":
			map_area.start_overwatch_selection(_w(card.throw_range), CONE_HALF_ANGLE)
			log_requested.emit("Elegí hacia dónde soplar.")
		"curse":
			map_area.start_push_enemy_selection(_w(card.throw_range))
			log_requested.emit("Elegí al enemigo.")
		"puddle_hop":
			map_area.start_spell_selection(_w(card.throw_range))
			log_requested.emit("Elegí el charco que querés trasladar.")
		"tree_climb":
			map_area.start_module_selection(_w(card.card_range))
			log_requested.emit("Elegí el árbol al que querés trepar.")
		_:
			map_area.start_spell_selection(_w(card.throw_range))
			log_requested.emit("Elegí el punto.")

func _on_spell_click(pos: Vector2) -> void:
	var card := pending_spell_card
	if card.card_type == "tree_climb":
		_on_tree_climb_click(card, pos)
		return
	if card.card_type == "puddle_hop" and pending_spell_puddle.is_empty():
		var zone: Dictionary = map_area.get_puddle_at(pos)
		if zone.is_empty():
			return
		var gap: float = map_area.movement_distance(map_area.player_pos, zone["pos"]) - float(zone["radius"])
		if gap > _w(card.throw_range):
			log_requested.emit("Ese charco está demasiado lejos.")
			return
		pending_spell_puddle = zone
		map_area.start_puddle_hop_landing(zone["pos"], _w(card.card_range))
		log_requested.emit("Elegí dónde cae el charco.")
		return
	match card.card_type:
		"puddle_hop":
			if map_area.movement_distance(pending_spell_puddle["pos"], pos) > _w(card.card_range):
				log_requested.emit("No llega tan lejos desde ese charco.")
				return
			if pos.x < 0.0 or pos.y < 0.0 or pos.x > map_area.WORLD_W or pos.y > map_area.WORLD_H:
				return
		"chain_bolt", "cone_blast":
			var dir: Vector2 = pos - map_area.player_pos
			if dir.length() < 0.2:
				return
			pending_spell_dir = dir.normalized()
		"curse":
			if not map_area.is_click_on_enemy(pos):
				return
			if not map_area.is_enemy_in_attack_range(_w(card.throw_range)):
				log_requested.emit("El enemigo está demasiado lejos.")
				return
			if not map_area.has_line_of_sight(map_area.player_pos, map_area.enemy_pos):
				log_requested.emit("No ves al enemigo desde acá.")
				return
		_:
			if map_area.movement_distance(map_area.player_pos, pos) > _w(card.throw_range):
				log_requested.emit("Demasiado lejos.")
				return
			# El meteoro cae del cielo; el resto necesita ver el punto.
			if card.card_type == "element_bolt" and not map_area.has_line_of_sight(map_area.player_pos, pos):
				log_requested.emit("Hay algo en el medio.")
				return
			if card.card_type == "blink" and not map_area.can_blink_to(pos):
				log_requested.emit("No podés aparecer ahí.")
				return
	pending_cell = pos
	confirm_popup_show_requested.emit(false)

func _execute_spell(cell: Vector2) -> void:
	var card: CardActionLine = state.turn_actions[pending_spell_index]
	var dir := pending_spell_dir
	var puddle := pending_spell_puddle
	var tree := pending_spell_tree
	state.turn_actions.remove_at(pending_spell_index)
	_clear_pending_spell()
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()
	if not card.card_type in ["blink", "delayed_area", "tree_climb"]:
		map_area.play_player_anim("range")
		await map_area.player_anim_finished
		map_area.play_player_anim("idle")
	match card.card_type:
		"element_bolt":
			await _cast_element_bolt(card, cell)
		"chain_bolt":
			await _cast_chain_bolt(card, dir)
		"delayed_area":
			# Deja charco solo si tiene duración (un charco permanente de un hechizo no).
			var effect := card.puddle_effect if card.duration > 0 else ""
			map_area.place_delayed_zone(cell, _w(card.card_range), card.damage, card.name,
				card.delay, effect, card.duration)
			log_requested.emit("%s: la zona está marcada. Cae en %d ronda(s)." % [card.name, maxi(1, card.delay)])
		"cone_blast":
			if card.status_effect == "burn" and map_area.ignite_trees_in_cone(map_area.player_pos, dir, _w(card.throw_range), CONE_HALF_ANGLE) > 0:
				log_requested.emit("%s: ¡un árbol se prende fuego!" % card.name)
			if map_area.is_enemy_in_cone(map_area.player_pos, dir, _w(card.throw_range), CONE_HALF_ANGLE):
				log_requested.emit("¡%s alcanza al enemigo — %d de daño!" % [card.name, card.damage])
				await _deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
				if card.status_effect != "ninguno" and state.enemy_hp > 0:
					_apply_spell_status(card.status_effect, maxi(1, card.duration))
			else:
				log_requested.emit("%s: no alcanzó a nadie." % card.name)
		"curse":
			if card.damage > 0:
				await _deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
			var turns: int = maxi(1, card.duration)
			if card.status_effect == "entangle" and map_area.is_tree_near(map_area.enemy_pos, TREE_ROOT_REACH):
				turns += TREE_ROOT_BONUS_TURNS
				log_requested.emit("Las raíces del árbol cercano ayudan a atraparlo.")
			_apply_spell_status(card.status_effect, turns)
		"blink":
			map_area.blink_player_to(cell)
			log_requested.emit("%s: aparecés en otro lugar." % card.name)
		"puddle_hop":
			await _cast_puddle_hop(card, puddle, cell)
		"tree_climb":
			state.player_in_tree = true
			state.player_tree_landing = cell
			state.player_tree_drop_damage = card.damage
			map_area.climb_tree(tree, cell)
			log_requested.emit("%s: estás arriba del árbol. Caés al terminar la ronda." % card.name)
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

## Chispa / Escarcha: daño mágico en un círculo y cambia los charcos que toca.
func _cast_element_bolt(card: CardActionLine, cell: Vector2) -> void:
	var radius := _w(card.card_range)
	var from_effects: Array = ELEMENT_CONVERSIONS.get(card.puddle_effect, [])
	var converted: int = map_area.convert_puddles(cell, radius, from_effects, card.puddle_effect)
	if converted > 0:
		log_requested.emit("%s: %d charco(s) cambiaron." % [card.name, converted])
	if card.puddle_effect == "fire" and map_area.ignite_trees_in_circle(cell, radius) > 0:
		log_requested.emit("%s: ¡un árbol se prende fuego!" % card.name)
	elif card.puddle_effect == "ice" and map_area.extinguish_trees_in_circle(cell, radius) > 0:
		log_requested.emit("%s: apagaste un árbol en llamas." % card.name)
	if not map_area.is_enemy_in_circle(cell, radius):
		log_requested.emit("%s: no le diste al enemigo." % card.name)
		return
	var was_wet: bool = state.enemy_wet_turns > 0
	log_requested.emit("¡%s le da al enemigo — %d de daño!" % [card.name, card.damage])
	await _deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
	if state.enemy_hp <= 0:
		return
	if card.puddle_effect == "ice" and was_wet:
		_apply_spell_status("freeze", FREEZE_TURNS)
	elif card.status_effect != "ninguno":
		_apply_spell_status(card.status_effect, maxi(1, card.duration))

## Descarga: rayo en línea. Pega doble a los mojados y se propaga por el agua
## que toca (a quien esté parado en ella, también a vos).
func _cast_chain_bolt(card: CardActionLine, dir: Vector2) -> void:
	var from: Vector2 = map_area.player_pos
	var to: Vector2 = from + dir * _w(card.throw_range)
	# Pararrayos: el rayo se frena en el primer árbol y le pega a quien esté arriba.
	var rod: Dictionary = map_area.first_tree_on_segment(from, to)
	if not rod.is_empty():
		to = from + (to - from) * float(rod["t"])
		log_requested.emit("%s: el rayo cae sobre un árbol." % card.name)
		if map_area.is_player_in_this_tree(rod["tree"]):
			log_requested.emit("¡Estabas arriba del árbol — %d de daño!" % card.damage)
			await _deal_damage_to_player.call(card.damage, true, CombatState.MAGICO)
	var water: Array = map_area.puddles_on_segment(from, to, ["wet"])
	var enemy_in_water: bool = map_area.is_pos_in_zones(map_area.enemy_pos, water)
	var hit_enemy: bool = map_area.segment_hits_enemy(from, to) or enemy_in_water
	var hit_player: bool = map_area.is_pos_in_zones(map_area.player_pos, water)
	if not hit_enemy and not hit_player:
		log_requested.emit("%s: no alcanzó a nadie." % card.name)
		return
	if hit_enemy:
		var dmg: int = card.damage * (2 if state.enemy_wet_turns > 0 or enemy_in_water else 1)
		log_requested.emit("¡%s electrocuta al enemigo — %d de daño!" % [card.name, dmg])
		await _deal_damage_to_enemy.call(dmg, true, CombatState.MAGICO)
	if hit_player and state.player_hp > 0:
		var own: int = card.damage * 2
		log_requested.emit("¡%s! La descarga volvió por el agua — %d de daño a vos." % [card.name, own])
		await _deal_damage_to_player.call(own, true, CombatState.MAGICO)

## Trepar árbol: primero el árbol (pegado a vos), después dónde caer (dentro
## del rango alrededor del árbol: un lugar libre o encima del enemigo).
func _on_tree_climb_click(card: CardActionLine, pos: Vector2) -> void:
	if pending_spell_tree.is_empty():
		var tree: Dictionary = map_area.get_tree_at(pos)
		if tree.is_empty():
			return
		if map_area.obstacle_gap(tree) > _w(card.card_range):
			log_requested.emit("Tenés que estar pegado al árbol para trepar.")
			return
		if map_area.is_tree_burning(tree):
			log_requested.emit("Ese árbol está en llamas: no podés trepar.")
			return
		pending_spell_tree = tree
		map_area.start_puddle_hop_landing(tree["pos"], _w(card.throw_range))
		log_requested.emit("Elegí dónde vas a caer al final de la ronda.")
		return
	if map_area.movement_distance(pending_spell_tree["pos"], pos) > _w(card.throw_range):
		log_requested.emit("No llegás a caer tan lejos.")
		return
	if not map_area.can_drop_at(pos):
		log_requested.emit("No podés caer ahí.")
		return
	pending_cell = pos
	confirm_popup_show_requested.emit(false)

## Traslado de charco: el charco salta a `cell`. Si le cae encima al enemigo,
## le aplica el estado de ese charco (PUDDLE_IMPACTS); el hielo cae como granizo.
func _cast_puddle_hop(card: CardActionLine, puddle: Dictionary, cell: Vector2) -> void:
	var effect: String = puddle.get("effect", "wet")
	var zone_damage: int = puddle.get("damage", 0)
	var landed: Dictionary = map_area.move_puddle(puddle, cell)
	if not map_area.is_enemy_in_circle(cell, landed.get("radius", 0.0)):
		log_requested.emit("%s: el charco cayó en otro lugar." % card.name)
		return
	if effect == "ice":
		log_requested.emit("¡%s! Cae granizo sobre el enemigo — %d de daño." % [card.name, card.damage])
		await _deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
		return
	log_requested.emit("¡%s! El charco le cae encima al enemigo." % card.name)
	var fx: Array = state.puddle_impact_on_enemy(effect, zone_damage)
	if not fx.is_empty() and fx[1] > 0:
		log_requested.emit("El enemigo queda %s por %d turnos." % [STATUS_NAMES.get(fx[0], fx[0]), fx[1]])

## Nova: daño mágico alrededor tuyo y empuja al enemigo hacia afuera.
func _execute_nova(card: CardActionLine) -> void:
	var radius := _w(card.card_range)
	if not map_area.is_enemy_in_circle(map_area.player_pos, radius):
		log_requested.emit("%s: no había nadie cerca." % card.name)
		return
	log_requested.emit("¡%s! El enemigo sale despedido — %d de daño." % [card.name, card.damage])
	await _deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
	if state.enemy_hp <= 0:
		_check_combat_end.call()
		return
	var from: Vector2 = map_area.enemy_pos
	var away: Vector2 = from + (from - map_area.player_pos)
	var landing: Vector2 = map_area.calculate_push_landing(away, _w(card.throw_range))
	map_area.push_enemy_to(landing)
	await map_area.enemy_reached_target
	await _apply_enemy_forced_move(card.name, from, landing)
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	_check_combat_end.call()

func _apply_spell_status(effect: String, base_turns: int) -> void:
	var turns: int = state.set_enemy_status(effect, base_turns)
	if turns > 0:
		log_requested.emit("El enemigo queda %s por %d turnos." % [STATUS_NAMES.get(effect, effect), turns])

const STATUS_NAMES := {
	"bleed": "sangrando",
	"blind": "cegado", "slow": "ralentizado", "entangle": "enredado", "burn": "en llamas",
	"poison": "envenenado", "freeze": "congelado", "wet": "mojado",
}

func _clear_pending_spell() -> void:
	if pending_spell_index >= 0:
		map_area.clear_spell_selection()
		map_area.clear_push_selection()
	pending_spell_index = -1
	pending_spell_card = null
	pending_spell_dir = Vector2.ZERO
	pending_spell_puddle = {}
	pending_spell_tree = {}

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
	state.player_overwatch_damage_type = card.damage_type
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
	map_area.place_puddle(cell, _w(card.card_range), card.puddle_effect, card.duration, card.damage)
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
		await _deal_damage_to_enemy.call(card.damage, false, card.damage_type)
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
		await _deal_damage_to_enemy.call(card.damage, false, card.damage_type)
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
	var damage: int = card.damage
	var damage_type: String = card.damage_type
	var enchant_status := ""
	if state.player_enchant_damage > 0 and damage_type == CombatState.FISICO:
		# Encantar arma: este golpe es mágico, pega más y aplica su estado.
		damage += state.player_enchant_damage
		damage_type = CombatState.MAGICO
		enchant_status = state.player_enchant_status
		state.player_enchant_damage = 0
		state.player_enchant_status = ""
		log_requested.emit("¡El arma encantada brilla!")
	log_requested.emit("Played %s for %d damage." % [card.name, damage])
	# La acción se gasta antes de la animación: durante el await el jugador puede
	# elegir otra mitad o terminar el turno y state.turn_actions cambia.
	state.turn_actions.remove_at(pending_attack_index)
	clear_pending_attack()
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()
	await _deal_damage_to_enemy.call(damage, false, damage_type)
	if enchant_status != "" and state.enemy_hp > 0:
		_apply_spell_status(enchant_status, 3)
	ui_update_requested.emit()
	_check_combat_end.call()

func _confirm_self_action() -> void:
	if pending_self_index < 0 or pending_self_index >= state.turn_actions.size():
		pending_self_index = -1
		map_area.clear_self_highlight()
		return
	var card: CardActionLine = state.turn_actions[pending_self_index]
	if card.card_type == "heal":
		var healed: int = state.heal_player(card.restore_amount)
		log_requested.emit("Played %s. Te curás %d (%d/%d)." % [card.name, healed, state.player_hp, state.player_max_hp])
	elif card.card_type == "enchant":
		state.player_enchant_damage = card.damage
		state.player_enchant_status = "" if card.status_effect == "ninguno" else card.status_effect
		log_requested.emit("Played %s. Tu próximo ataque físico es mágico y suma %d de daño." % [card.name, card.damage])
	elif card.card_type == "nova":
		_execute_nova.call_deferred(card)
	elif card.card_type == "counter":
		state.player_counter_damage += card.damage
		log_requested.emit("Played %s. Contraataque listo: %d de daño a quien te pegue cuerpo a cuerpo." % [card.name, state.player_counter_damage])
	elif card.card_type == "mp_restore":
		var gained: int = state.restore_mp(card.restore_amount)
		log_requested.emit("Played %s. Recuperás %d MP (%d/%d)." % [card.name, gained, state.player_mp, state.player_max_mp])
	elif card.card_type == "ward":
		state.player_ward += card.block_amount
		log_requested.emit("Played %s. Escudo mágico: %d" % [card.name, state.player_ward])
	else:
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
	confirm_popup_hide_requested.emit()
	pending_cell = Vector2(-1.0, -1.0)
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
	_clear_pending_module()
	_clear_pending_spell()
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
	confirm_popup_hide_requested.emit()
	pending_cell = Vector2(-1.0, -1.0)
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
	_clear_pending_module()
	_clear_pending_spell()
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
