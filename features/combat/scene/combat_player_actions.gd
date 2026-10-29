class_name CombatPlayerActions
extends RefCounted

const SelectionCoordinatorScript := preload("res://features/combat/scene/combat_player_selection_coordinator.gd")
const BoardEffectsScript := preload("res://features/combat/scene/combat_player_board_effects.gd")
const PendingExecutorScript := preload("res://features/combat/scene/combat_pending_action_executor.gd")

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
## Las acciones del jugador necesitan el mismo contrato liviano que la IA.
## `MapArea` lo implementa en juego; los tests pueden usar `CombatMapArea`.
var map_area: CombatMapArea
var board: CombatBoardContext
var zone_effects := CombatZoneEffectResolver.new()

var deal_damage_to_enemy: Callable
var deal_damage_to_player: Callable
var check_combat_end: Callable
var get_flow: Callable
var flow_is_active: Callable

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
var _selection_coordinator
var _board_effects
var _pending_executor

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
	_selection_coordinator = SelectionCoordinatorScript.new(self)
	_board_effects = BoardEffectsScript.new(self)
	_pending_executor = PendingExecutorScript.new(self)
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

func setup(p_state: CombatState, p_map_area: CombatMapArea, p_damage_enemy: Callable, p_damage_player: Callable, p_check_end: Callable,
		p_get_flow: Callable = Callable(), p_flow_is_active: Callable = Callable()) -> void:
	state = p_state
	map_area = p_map_area
	board = CombatBoardContext.new(p_map_area.state, p_map_area.queries, p_map_area.actors,
		p_map_area.selection, p_map_area.placement, p_map_area.effects, p_map_area.obstacles,
		p_map_area.push, p_map_area.presentation, p_map_area.movement, p_map_area.terrain,
		p_map_area.scene if p_map_area.scene != null else p_map_area)
	deal_damage_to_enemy = p_damage_enemy
	deal_damage_to_player = p_damage_player
	check_combat_end = p_check_end
	get_flow = p_get_flow
	flow_is_active = p_flow_is_active


func current_flow() -> AsyncFlowToken:
	return get_flow.call() as AsyncFlowToken if get_flow.is_valid() else null


func is_flow_active(flow: AsyncFlowToken) -> bool:
	return flow_is_active.call(flow) if flow_is_active.is_valid() else true

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
	_selection_coordinator.play_as_move(index)

func play_card(index: int) -> void:
	_selection_coordinator.play_card(index)

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
	board.presentation.targeting.overlay.path.clear_path_preview()
	_execute_tile_action(cell)

func reject_confirmation() -> void:
	confirm_popup_hide_requested.emit()
	board.presentation.targeting.overlay.path.clear_path_preview()
	pending_cell = Vector2(-1.0, -1.0)

func finish_selection() -> void:
	confirm_popup_hide_requested.emit()
	board.presentation.targeting.overlay.path.clear_path_preview()
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
	_pending_executor.execute(cell)

## Ejecuta inmediatamente la selección activa. Es útil para entradas no-UI y
## conserva el mismo cierre de estado que una confirmación normal.
func execute_selection_at(cell: Vector2) -> void:
	_execute_tile_action(cell)

## Variante esperable para acciones que reproducen una animación antes de
## terminar (por ejemplo, ataques). La UI puede seguir usando la versión
## inmediata; las pruebas y flujos secuenciales esperan su finalización.
func execute_selection_at_async(cell: Vector2) -> void:
	await _pending_executor.execute_async(cell)

func active_selection_index() -> int:
	return _pending_executor.active_index()

func active_selection_range_cells() -> int:
	return _pending_executor.active_range_cells()

## Los charcos que pisó el jugador entre `from` y `to` le aplican sus estados
## (al moverse, o al caer de un árbol: from == to).
func apply_player_zone_effects(from: Vector2, to: Vector2) -> void:
	_board_effects.apply_player_zone_effects(from, to)

## Talar: el árbol cae alejándose del jugador y queda un tronco tirado.
func _fell_tree(card: CardActionLine, tree: Dictionary, flow: AsyncFlowToken) -> void:
	var result: Dictionary = board.obstacles.fell_tree(tree, tree["pos"] - map_area.player_pos)
	emit_log("combat.log.player.tree_felled", [card.name])
	if result["enemy_hit"]:
		emit_log("combat.log.player.tree_hits_enemy", [TREE_CRUSH_DAMAGE])
		await deal_damage_to_enemy.call(TREE_CRUSH_DAMAGE, true, CombatState.FISICO)
		if not is_flow_active(flow):
			return

## El jugador se cae del árbol (lo talaron o se prendió fuego): daño de caída
## y, si ardía, queda en llamas. map_area ya lo bajó al pie del árbol.
func player_falls_from_tree(burning: bool) -> void:
	await _board_effects.player_falls_from_tree(burning)

## El enemigo fue movido a la fuerza (empuje, tirón, ancla, nova): se le
## aplican los charcos y trampas que cruzó. Devuelve si pasó por alguno.
func _apply_enemy_forced_move(card_name: String, from: Vector2, landing: Vector2, flow: AsyncFlowToken) -> bool:
	return await _board_effects.apply_enemy_forced_move(card_name, from, landing, flow)

## Nova: daño mágico alrededor tuyo y empuja al enemigo hacia afuera.
func _execute_nova(card: CardActionLine) -> void:
	await _board_effects.execute_nova(card)

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
