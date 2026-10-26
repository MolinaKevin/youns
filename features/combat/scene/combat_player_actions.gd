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
var map_area: MapArea
var zone_effects := CombatZoneEffectResolver.new()

var deal_damage_to_enemy: Callable
var deal_damage_to_player: Callable
var check_combat_end: Callable

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
const CombatEffect := preload("res://features/combat/scene/combat_effect.gd")
const ELEMENT_CONVERSIONS := CombatEffect.ELEMENT_CONVERSIONS
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

func emit_log(key: String, args: Array = []) -> void:
	CombatLog.emit_requested(log_requested, key, args)

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

func setup(p_state: CombatState, p_map_area: MapArea, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable) -> void:
	state = p_state
	map_area = p_map_area
	deal_damage_to_enemy = p_damage_enemy
	deal_damage_to_player = p_damage_player
	check_combat_end = p_check_end

## Casillas de la grilla → unidades de mundo del mapa.
func w(cells: int) -> float:
	return CombatGrid.world_for(cells)

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

## Activa o desactiva el modo de usar una mitad de carta como movimiento.
func set_move_mode(pressed: bool) -> void:
	move_mode = pressed
	if not pressed:
		_move_action.clear()
		if _current_action == _move_action:
			_current_action = null

func play_as_move(index: int) -> void:
	var card = state.turn_actions[index]
	if state.player_overwatch_active:
		state.player_overwatch_active = false
		map_area.interactions.clear_overwatch_zone()
		emit_log("combat.log.player.overwatch_cancelled")
	if state.player_entangled_turns > 0:
		emit_log("combat.log.player.entangled_cannot_move", [state.player_entangled_turns])
		card_preview_hide_requested.emit()
		return
	if state.player_frozen_turns > 0:
		emit_log("combat.log.player.frozen_cannot_move", [state.player_frozen_turns])
		card_preview_hide_requested.emit()
		return
	if state.player_in_tree:
		emit_log("combat.log.player.in_tree_cannot_move")
		card_preview_hide_requested.emit()
		return
	card_preview_show_requested.emit(card)
	var penalty := _move_penalty()
	var effective_range := maxi(1, CardActionLine.movement_cells_for_modules(MOVE_MODE_MODULES) - penalty)
	if penalty > 0:
		emit_log("combat.log.player.movement_reduced")
	_move_action.configure(index, effective_range)
	_current_action = _move_action
	emit_log("combat.log.player.move_mode", [CardActionLine.movement_modules_label_for_cells(effective_range)])

func play_card(index: int) -> void:
	var card = state.turn_actions[index]

	if state.player_overwatch_active and card.card_type != CardActionLine.TYPE_OVERWATCH:
		state.player_overwatch_active = false
		map_area.interactions.clear_overwatch_zone()
		emit_log("combat.log.player.overwatch_cancelled")
	card_preview_show_requested.emit(card)
	if state.player_in_tree and card.card_type in TREE_BLOCKED_LINES:
		emit_log("combat.log.player.in_tree_cannot_move")
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
		emit_log("combat.log.player.entangled_cannot_move", [state.player_entangled_turns])
		card_preview_hide_requested.emit()
		return
	if state.player_frozen_turns > 0:
		emit_log("combat.log.player.frozen_cannot_move", [state.player_frozen_turns])
		card_preview_hide_requested.emit()
		return
	var penalty := _move_penalty()
	var effective_range := maxi(1, move_range_cells - penalty)
	if penalty > 0:
		emit_log("combat.log.player.movement_reduced")
	_move_action.configure(index, effective_range)
	_current_action = _move_action
	emit_log("combat.log.player.move_select", [card_name, CardActionLine.movement_modules_label_for_cells(effective_range)])

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

## Entrega una casilla al modo de selección activo.
func select_position(pos: Vector2) -> void:
	if _current_action == null:
		return
	var action := _current_action
	action.on_tile_selected(pos)
	if not action.is_active():
		_current_action = null

## Confirma la selección pendiente actual.
func confirm_selection() -> void:
	confirm_popup_hide_requested.emit()
	var cell := pending_cell
	pending_cell = Vector2(-1.0, -1.0)
	map_area.presentation.clear_path_preview()
	_execute_tile_action(cell)

func reject_confirmation() -> void:
	confirm_popup_hide_requested.emit()
	map_area.presentation.clear_path_preview()
	pending_cell = Vector2(-1.0, -1.0)

func finish_selection() -> void:
	confirm_popup_hide_requested.emit()
	map_area.presentation.clear_path_preview()
	pending_cell = Vector2(-1.0, -1.0)
	_finish_movement()

func finish_movement() -> void:
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

## Ejecuta inmediatamente la selección activa. Es útil para entradas no-UI y
## conserva el mismo cierre de estado que una confirmación normal.
func execute_selection_at(cell: Vector2) -> void:
	_execute_tile_action(cell)

## Variante esperable para acciones que reproducen una animación antes de
## terminar (por ejemplo, ataques). La UI puede seguir usando la versión
## inmediata; las pruebas y flujos secuenciales esperan su finalización.
func execute_selection_at_async(cell: Vector2) -> void:
	if _current_action == null:
		return
	var action := _current_action
	await action.execute(cell)
	if not action.is_active():
		_current_action = null

func active_selection_index() -> int:
	return _current_action.index if _current_action != null else -1

func active_selection_range_cells() -> int:
	if _current_action == null:
		return -1
	var range_value: Variant = _current_action.get("range_cells")
	return int(range_value) if range_value != null else -1

## Los charcos que pisó el jugador entre `from` y `to` le aplican sus estados
## (al moverse, o al caer de un árbol: from == to).
func apply_player_zone_effects(from: Vector2, to: Vector2) -> void:
	var contact_margin: float = map_area.queries.player_area_contact_radius()
	var zone_fx: Dictionary = map_area.interactions.puddle_effects_along(from, to, contact_margin)
	var zone_dmg: Dictionary = map_area.interactions.puddle_damage_along(from, to, contact_margin)
	for event in zone_effects.apply_path_effects(state, zone_fx, zone_dmg, true):
		zone_effects.log_zone_effect(event, "combat.log.player.zone", CombatZoneEffectResolver.PLAYER_LOG_TURNS, emit_log)

## Talar: el árbol cae alejándose del jugador y queda un tronco tirado.
func _fell_tree(card: CardActionLine, tree: Dictionary) -> void:
	var result: Dictionary = map_area.interactions.fell_tree(tree, tree["pos"] - map_area.player_pos)
	emit_log("combat.log.player.tree_felled", [card.name])
	if result["enemy_hit"]:
		emit_log("combat.log.player.tree_hits_enemy", [TREE_CRUSH_DAMAGE])
		await deal_damage_to_enemy.call(TREE_CRUSH_DAMAGE, true, CombatState.FISICO)

## El jugador se cae del árbol (lo talaron o se prendió fuego): daño de caída
## y, si ardía, queda en llamas. map_area ya lo bajó al pie del árbol.
func player_falls_from_tree(burning: bool) -> void:
	if not state.player_in_tree:
		return
	state.player_in_tree = false
	emit_log("combat.log.player.tree_fall", [TREE_FALL_DAMAGE])
	await deal_damage_to_player.call(TREE_FALL_DAMAGE, true, CombatState.FISICO)
	if burning and state.player_hp > 0:
		var turns: int = state.set_player_status("burn", TREE_FIRE_BURN_TURNS)
		emit_log("combat.log.player.burning_tree_fall", [turns])
	if state.player_hp > 0:
		apply_player_zone_effects(map_area.player_pos, map_area.player_pos)
	ui_update_requested.emit()
	check_combat_end.call()

## El enemigo fue movido a la fuerza (empuje, tirón, ancla, nova): se le
## aplican los charcos y trampas que cruzó. Devuelve si pasó por alguno.
func _apply_enemy_forced_move(card_name: String, from: Vector2, landing: Vector2) -> bool:
	var contact_margin: float = map_area.queries.enemy_area_contact_radius()
	var fx: Dictionary = map_area.interactions.zone_effects_along(from, landing, contact_margin)
	var zone_dmg: Dictionary = map_area.interactions.puddle_damage_along(from, landing, contact_margin)
	var events := zone_effects.apply_path_effects(state, fx, zone_dmg, false)
	for event in events:
		zone_effects.log_zone_effect(event, "combat.log.enemy.forced_zone", CombatZoneEffectResolver.ENEMY_LOG_TURNS, emit_log)
	var any_zone := not events.is_empty()
	if fx.get("trap_damage", 0) > 0:
		emit_log("combat.log.player.enemy_forced_trap", [card_name, fx["trap_damage"]])
		await deal_damage_to_enemy.call(fx["trap_damage"])
		any_zone = true
	return any_zone

## Nova: daño mágico alrededor tuyo y empuja al enemigo hacia afuera.
func _execute_nova(card: CardActionLine) -> void:
	var radius := w(card.primary_range_cells())
	var in_pattern: bool = map_area.interactions.is_enemy_in_card_pattern(card.pattern, map_area.player_pos, Vector2(0, 1), radius) if card.pattern != null else map_area.queries.is_enemy_in_area_circle(map_area.player_pos, radius)
	if not in_pattern:
		emit_log("combat.log.player.nova_no_target", [card.name])
		return
	emit_log("combat.log.player.nova_hits_enemy", [card.name, card.damage])
	await deal_damage_to_enemy.call(card.damage, true, CombatState.MAGICO)
	if state.enemy_hp <= 0:
		check_combat_end.call()
		return
	var from: Vector2 = map_area.enemy_pos
	var away: Vector2 = from + (from - map_area.player_pos)
	var landing: Vector2 = map_area.interactions.calculate_push_landing(away, w(card.cast_range_cells()))
	map_area.interactions.push_enemy_to(landing)
	await map_area.enemy_reached_target
	await _apply_enemy_forced_move(card.name, from, landing)
	hand_refresh_requested.emit()
	ui_update_requested.emit()
	check_combat_end.call()

func _apply_spell_status(effect: String, base_turns: int) -> void:
	var turns: int = state.set_enemy_status(effect, base_turns)
	if turns > 0:
		emit_log("combat.status.enemy_applied", [LocalizationState.t("combat.status_name.%s" % effect), turns])

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
