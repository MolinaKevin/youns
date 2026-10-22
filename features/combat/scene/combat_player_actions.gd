class_name CombatPlayerActions
extends RefCounted

# Las acciones espaciales internas usan celdas de CombatGrid. Las líneas
# "move" se presentan y se configuran en módulos (8 celdas por módulo).
const MOVE_MODE_MODULES   := 5    # "Mover" con cualquier mitad
## Alcance fijo de contacto: no escala con estadísticas.
const MELEE_RANGE_MODULES := 2
const NEARBY_TRAP_MODULES := 2    # trampa colocada "cerca"
const WET_MOVE_PENALTY_MODULES := 2
const GREASY_MOVE_PENALTY_MODULES := 3
const BLINDED_RANGE_MODULES := 2  # rango máximo estando cegado

var state: CombatState
var map_area: Node
var zone_effects := CombatZoneEffectResolver.new()

var _deal_damage_to_enemy: Callable
var _deal_damage_to_player: Callable
var _check_combat_end: Callable

var move_mode := false

## Cada familia de carta vive en su propio resolver (ver
## features/combat/scene/pending_actions/) con una interfaz común
## (start/on_tile_selected/execute/clear). `_current_action` es la única
## referencia a cuál está activo — antes esto eran ~30 campos pending_*
## sueltos que había que enumerar a mano en cada lugar que necesitaba saber
## "¿hay algo pendiente?" o "cancelá lo que esté pendiente".
var _move_action: CombatMoveAction
var _attack_action: CombatAttackAction
var _grenade_action: CombatGrenadeAction
var _trap_action: CombatTrapAction
var _self_action: CombatSelfAction
var _jump_action: CombatJumpAction
var _push_action: CombatPushAction
var _module_action: CombatModuleAction
var _spell_action: CombatSpellAction
var _puddle_action: CombatPuddleAction
var _overwatch_action: CombatOverwatchAction
var _all_actions: Array[CombatPendingAction] = []
var _current_action: CombatPendingAction = null

var pending_cell := Vector2(-1.0, -1.0)

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
const TREE_BLOCKED_LINES := [CardActionLine.TYPE_MOVE, CardActionLine.TYPE_BLINK, CardActionLine.TYPE_ROCK_JUMP, CardActionLine.TYPE_TREE_CLIMB]


## Qué charcos cambia cada hechizo elemental (element_bolt, según puddle_effect).
const ELEMENT_CONVERSIONS := {"fire": ["grease", "vine"], "ice": ["wet"]}
## Ancho (medio ángulo) de los hechizos en línea y en cono.
const BOLT_HALF_ANGLE := 4.0
const CONE_HALF_ANGLE := 30.0
## Turnos base que congela Escarcha a un enemigo mojado.
const FREEZE_TURNS := 2

const STATUS_NAMES := {
	"bleed": "sangrando",
	"blind": "cegado", "slow": "ralentizado", "entangle": "enredado", "burn": "en llamas",
	"poison": "envenenado", "freeze": "congelado", "wet": "mojado",
}

signal log_requested(text: String)
signal hand_refresh_requested()
signal ui_update_requested()
signal card_preview_show_requested(card: CardActionLine)
signal card_preview_hide_requested()
signal confirm_popup_show_requested(show_fin_button: bool)
signal confirm_popup_hide_requested()
signal end_move_button_visible_changed(visible: bool)
signal move_mode_button_reset_requested()

func _init() -> void:
	_move_action = CombatMoveAction.new(self)
	_attack_action = CombatAttackAction.new(self)
	_grenade_action = CombatGrenadeAction.new(self)
	_trap_action = CombatTrapAction.new(self)
	_self_action = CombatSelfAction.new(self)
	_jump_action = CombatJumpAction.new(self)
	_push_action = CombatPushAction.new(self)
	_module_action = CombatModuleAction.new(self)
	_spell_action = CombatSpellAction.new(self)
	_puddle_action = CombatPuddleAction.new(self)
	_overwatch_action = CombatOverwatchAction.new(self)
	_all_actions = [_move_action, _attack_action, _grenade_action, _trap_action, _self_action,
		_jump_action, _push_action, _module_action, _spell_action, _puddle_action, _overwatch_action]

func setup(p_state: CombatState, p_map_area: Node, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	_deal_damage_to_enemy = p_damage_enemy
	_deal_damage_to_player = p_damage_player
	_check_combat_end = p_check_end

## Casillas de la grilla → unidades de mundo del mapa.
func _w(cells: int) -> float:
	return float(cells) * CombatGrid.CELL

func _move_penalty() -> int:
	return (CardActionLine.cells_for_modules(WET_MOVE_PENALTY_MODULES) if state.player_wet_turns > 0 else 0) \
		+ (CardActionLine.cells_for_modules(GREASY_MOVE_PENALTY_MODULES) if state.player_greasy_turns > 0 else 0)

# ── Card selection ────────────────────────────────────────────────────────────

func start_line(card: CardActionLine) -> void:
	if has_pending_selection():
		cancel_selection()
	var index: int = state.turn_actions.find(card)
	if index == -1:
		return
	if move_mode:
		play_as_move(index)
	else:
		play_card(index)

func has_pending_selection() -> bool:
	return _current_action != null

func _on_move_mode_toggled(pressed: bool) -> void:
	move_mode = pressed
	if not pressed:
		_move_action.clear()
		if _current_action == _move_action:
			_current_action = null

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
	if state.player_in_tree:
		log_requested.emit("Estás arriba del árbol: no te podés mover hasta caer.")
		card_preview_hide_requested.emit()
		return
	card_preview_show_requested.emit(card)
	var penalty := _move_penalty()
	var effective_range := maxi(1, CardActionLine.movement_cells_for_modules(MOVE_MODE_MODULES) - penalty)
	if penalty > 0:
		log_requested.emit("Movimiento reducido por estado.")
	_move_action.configure(index, effective_range)
	_current_action = _move_action
	log_requested.emit("Modo mover: elegí un destino hasta %s módulos." % CardActionLine.movement_modules_label_for_cells(effective_range))

func play_card(index: int) -> void:
	var card = state.turn_actions[index]

	if state.player_overwatch_active and card.card_type != CardActionLine.TYPE_OVERWATCH:
		state.player_overwatch_active = false
		map_area.clear_overwatch_zone()
		log_requested.emit("Vigilancia cancelada.")
	card_preview_show_requested.emit(card)
	if state.player_in_tree and card.card_type in TREE_BLOCKED_LINES:
		log_requested.emit("Estás arriba del árbol: no te podés mover hasta caer.")
		card_preview_hide_requested.emit()
		return
	match card.card_type:
		CardActionLine.TYPE_MOVE:
			start_move_selection("hand", index, card.movement_range_cells(), card.name)
		CardActionLine.TYPE_MELEE_ATTACK:
			var r: int = card.primary_range_cells() if card.primary_range_cells() > 0 else CardActionLine.cells_for_modules(MELEE_RANGE_MODULES)
			start_range_attack_selection(index, card, r)
		CardActionLine.TYPE_RANGE_ATTACK:
			start_range_attack_selection(index, card, card.primary_range_cells())
		CardActionLine.TYPE_GRENADE:
			start_grenade_selection(index, card)
		CardActionLine.TYPE_TRAP_PLACE:
			start_trap_selection(index, card, true)
		CardActionLine.TYPE_TRAP_THROW:
			start_trap_selection(index, card, false)
		CardActionLine.TYPE_BLOCK, CardActionLine.TYPE_WARD, CardActionLine.TYPE_MP_RESTORE, CardActionLine.TYPE_COUNTER, CardActionLine.TYPE_NOVA, CardActionLine.TYPE_HEAL, CardActionLine.TYPE_ENCHANT:
			start_self_selection(index, card)
		CardActionLine.TYPE_ELEMENT_BOLT, CardActionLine.TYPE_CHAIN_BOLT, CardActionLine.TYPE_DELAYED_AREA, CardActionLine.TYPE_CONE_BLAST, CardActionLine.TYPE_CURSE, CardActionLine.TYPE_BLINK, CardActionLine.TYPE_PUDDLE_HOP, CardActionLine.TYPE_TREE_CLIMB:
			_start_spell_selection(index, card)
		CardActionLine.TYPE_ROCK_JUMP:
			start_rock_jump_selection(index, card)
		CardActionLine.TYPE_PUSH, CardActionLine.TYPE_PULL, CardActionLine.TYPE_ANCHOR:
			start_push_selection(index, card)
		CardActionLine.TYPE_BREAK, CardActionLine.TYPE_MODULE_PUSH, CardActionLine.TYPE_BUILD, CardActionLine.TYPE_MODULE_THROW, CardActionLine.TYPE_COLLAPSE:
			_module_action.start(index, card)
			_current_action = _module_action
		CardActionLine.TYPE_PUDDLE:
			start_puddle_selection(index, card)
		CardActionLine.TYPE_OVERWATCH:
			start_overwatch_selection(index, card)

# ── Selection starters ────────────────────────────────────────────────────────

func start_move_selection(_section_name: String, index: int, move_range_cells: int, card_name: String) -> void:
	if state.player_entangled_turns > 0:
		log_requested.emit("¡Estás enredado! No podés moverte (%d turnos)." % state.player_entangled_turns)
		card_preview_hide_requested.emit()
		return
	if state.player_frozen_turns > 0:
		log_requested.emit("¡Estás congelado! No podés moverte (%d turnos)." % state.player_frozen_turns)
		card_preview_hide_requested.emit()
		return
	var penalty := _move_penalty()
	var effective_range := maxi(1, move_range_cells - penalty)
	if penalty > 0:
		log_requested.emit("Movimiento reducido por estado.")
	_move_action.configure(index, effective_range)
	_current_action = _move_action
	log_requested.emit("%s: elegí un destino hasta %s módulos." % [card_name, CardActionLine.movement_modules_label_for_cells(effective_range)])

func start_range_attack_selection(index: int, card: CardActionLine, range_override: int = 0) -> void:
	_attack_action.start(index, card, range_override)
	_current_action = _attack_action

func start_grenade_selection(index: int, card: CardActionLine) -> void:
	_grenade_action.start(index, card)
	_current_action = _grenade_action

func start_trap_selection(index: int, card: CardActionLine, nearby: bool) -> void:
	_trap_action.start(index, card, nearby)
	_current_action = _trap_action

func start_self_selection(index: int, card: CardActionLine) -> void:
	_self_action.start(index, card)
	_current_action = _self_action

func start_push_selection(index: int, card: CardActionLine) -> void:
	_push_action.start(index, card)
	_current_action = _push_action

func start_overwatch_selection(index: int, card: CardActionLine) -> void:
	_overwatch_action.start(index, card)
	_current_action = _overwatch_action

func start_puddle_selection(index: int, card: CardActionLine) -> void:
	_puddle_action.start(index, card)
	_current_action = _puddle_action

func start_rock_jump_selection(index: int, card: CardActionLine) -> void:
	if _jump_action.start(index, card):
		_current_action = _jump_action

func _start_spell_selection(index: int, card: CardActionLine) -> void:
	_spell_action.start(index, card)
	_current_action = _spell_action

# ── Map tile selected & confirm popup ─────────────────────────────────────────

func _on_position_selected(pos: Vector2) -> void:
	if _current_action == null:
		return
	var action := _current_action
	action.on_tile_selected(pos)
	if not action.is_active():
		_current_action = null

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
	_move_action.clear()
	if _current_action == _move_action:
		_current_action = null
	if move_mode:
		move_mode_button_reset_requested.emit()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

# ── Execute actions ───────────────────────────────────────────────────────────

func _execute_tile_action(cell: Vector2) -> void:
	if _current_action == null:
		return
	var action := _current_action
	action.execute(cell)
	if not action.is_active():
		_current_action = null

## Los charcos que pisó el jugador entre `from` y `to` le aplican sus estados
## (al moverse, o al caer de un árbol: from == to).
func apply_player_zone_effects(from: Vector2, to: Vector2) -> void:
	var contact_margin: float = map_area.player_area_contact_radius()
	var zone_fx: Dictionary = map_area.get_puddle_effects_along(from, to, contact_margin)
	var zone_dmg: Dictionary = map_area.get_puddle_damage_along(from, to, contact_margin)
	for event in zone_effects.apply_path_effects(state, zone_fx, zone_dmg, true):
		_log_player_zone_effect(event)

func _log_player_zone_effect(event: Dictionary) -> void:
	match event["effect"]:
		"wet": log_requested.emit("¡Pisaste el charco! Estás mojado por %d turnos." % event["turns"])
		"fire": log_requested.emit("¡Pisaste fuego! Estás en llamas por %d turnos." % event["turns"])
		"grease": log_requested.emit("¡Pisaste grasa! Movimiento reducido por %d turnos." % event["turns"])
		"vine": log_requested.emit("¡Las enredaderas te atraparon! No podés moverte por %d turnos." % event["turns"])
		"blood": log_requested.emit("¡Pisaste sangre! Estás sangrando por %d turnos." % event["turns"])
		"poison": log_requested.emit("¡Pisaste veneno! Estás envenenado (%d acumulaciones)." % event["turns"])
		"sand": log_requested.emit("¡Arena en los ojos! Rango de ataque reducido a 1 por %d turnos." % event["turns"])
		"ice": log_requested.emit("¡Pisaste hielo! Estás congelado por %d turnos." % event["turns"])
		"bloody_ice": log_requested.emit("¡Pisaste hielo sangriento! Congelado y sangrando.")
		"dark_smoke": log_requested.emit("¡Humo oscuro! No podés ver bien por %d turnos." % event["turns"])

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

## El enemigo fue movido a la fuerza (empuje, tirón, ancla, nova): se le
## aplican los charcos y trampas que cruzó. Devuelve si pasó por alguno.
func _apply_enemy_forced_move(card_name: String, from: Vector2, landing: Vector2) -> bool:
	var contact_margin: float = map_area.enemy_area_contact_radius()
	var fx: Dictionary = map_area.trigger_zone_effects_along(from, landing, contact_margin)
	var zone_dmg: Dictionary = map_area.get_puddle_damage_along(from, landing, contact_margin)
	var events := zone_effects.apply_path_effects(state, fx, zone_dmg, false)
	for event in events:
		_log_enemy_forced_zone_effect(event)
	var any_zone := not events.is_empty()
	if fx.get("trap_damage", 0) > 0:
		log_requested.emit("¡%s! El enemigo pasó por una trampa — %d de daño!" % [card_name, fx["trap_damage"]])
		await _deal_damage_to_enemy.call(fx["trap_damage"])
		any_zone = true
	return any_zone

func _log_enemy_forced_zone_effect(event: Dictionary) -> void:
	match event["effect"]:
		"wet": log_requested.emit("El enemigo pasó por agua. ¡Está mojado!")
		"fire": log_requested.emit("El enemigo pasó por el fuego. ¡Está en llamas!")
		"grease": log_requested.emit("El enemigo pasó por grasa. ¡Movimiento reducido!")
		"vine": log_requested.emit("¡El enemigo quedó enredado por %d turnos!" % event["turns"])
		"blood": log_requested.emit("El enemigo pasó por sangre. ¡Está sangrando!")
		"poison": log_requested.emit("El enemigo pasó por veneno. ¡Está envenenado!")
		"sand": log_requested.emit("¡El enemigo fue cegado por %d turnos!" % event["turns"])
		"ice": log_requested.emit("¡El enemigo pisó hielo y quedó congelado por %d turnos!" % event["turns"])
		"bloody_ice": log_requested.emit("¡El enemigo pisó hielo sangriento! Congelado y sangrando.")
		"dark_smoke": log_requested.emit("¡El enemigo quedó cegado por el humo oscuro!")

## Nova: daño mágico alrededor tuyo y empuja al enemigo hacia afuera.
func _execute_nova(card: CardActionLine) -> void:
	var radius := _w(card.primary_range_cells())
	var in_pattern: bool = map_area.is_enemy_in_card_pattern(card.pattern, map_area.player_pos, Vector2(0, 1), radius) if card.pattern != null else map_area.is_enemy_in_area_circle(map_area.player_pos, radius)
	if not in_pattern:
		log_requested.emit("%s: no había nadie cerca." % card.name)
		return
	log_requested.emit("¡%s! El enemigo sale despedido — %d de daño." % [card.name, card.damage])
	await _deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
	if state.enemy_hp <= 0:
		_check_combat_end.call()
		return
	var from: Vector2 = map_area.enemy_pos
	var away: Vector2 = from + (from - map_area.player_pos)
	var landing: Vector2 = map_area.calculate_push_landing(away, _w(card.cast_range_cells()))
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

# ── Clear pending ─────────────────────────────────────────────────────────────

func cancel_selection() -> void:
	confirm_popup_hide_requested.emit()
	pending_cell = Vector2(-1.0, -1.0)
	if _current_action == _move_action and _move_action.started:
		_finish_movement()
		return
	if _current_action:
		_current_action.clear()
		_current_action = null
	card_preview_hide_requested.emit()
	hand_refresh_requested.emit()
	ui_update_requested.emit()

func reset() -> void:
	confirm_popup_hide_requested.emit()
	pending_cell = Vector2(-1.0, -1.0)
	card_preview_hide_requested.emit()
	for action in _all_actions:
		action.clear()
	_current_action = null
	move_mode_button_reset_requested.emit()
	move_mode = false
