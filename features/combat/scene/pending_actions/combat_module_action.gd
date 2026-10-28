class_name CombatModuleAction
extends CombatPendingAction

## break, module_push, build, module_throw y collapse. Golpear y lanzar tienen
## dos pasos: elegir el módulo (fase 0) y después la dirección o el punto de
## caída (fase 1). build y collapse son de un solo paso. El efecto de cada
## uno una vez confirmado el módulo/punto vive en CombatModuleCasts
## (combat_module_casts.gd).

var phase: int = 0
var target: Dictionary = {}

var _casts: CombatModuleCasts

func _init(p_host: CombatPlayerActions) -> void:
	super._init(p_host)
	_casts = CombatModuleCasts.new(p_host)

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	phase = 0
	card = p_card
	target = {}
	if card.card_type == CardActionLine.TYPE_COLLAPSE:
		host.board.selection.actions.modes.actions.start_collapse_selection(host.w(card.primary_range_cells()))
	else:
		host.board.selection.actions.modes.actions.start_module_selection(host.w(card.primary_range_cells()))
	match card.card_type:
		CardActionLine.TYPE_BREAK: host.emit_log("combat.log.module.select_break")
		CardActionLine.TYPE_MODULE_PUSH: host.emit_log("combat.log.module.select_push")
		CardActionLine.TYPE_BUILD: host.emit_log("combat.log.module.select_build")
		CardActionLine.TYPE_MODULE_THROW: host.emit_log("combat.log.module.select_throw")
		CardActionLine.TYPE_COLLAPSE: host.emit_log("combat.log.module.select_collapse")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_BUILD:
		if host.board.queries.actors.movement_distance(host.board.state.player_position(), pos) > host.w(card.primary_range_cells()):
			host.emit_log("combat.log.module.build_too_far")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if card.card_type == CardActionLine.TYPE_COLLAPSE:
		if not host.board.selection.targeting.queries.is_click_on_enemy(pos):
			return
		if not host.board.queries.actors.is_enemy_in_attack_range(host.w(card.primary_range_cells())):
			host.emit_log("combat.log.module.enemy_too_far")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if phase == 1 and card.card_type == CardActionLine.TYPE_MODULE_THROW:
		# Lanzar: elegir dónde cae.
		if host.board.queries.actors.movement_distance(host.board.state.player_position(), pos) > host.w(card.cast_range_cells()):
			host.emit_log("combat.log.module.throw_too_far")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if phase == 1:
		# Golpe: elegir la dirección dentro del cono.
		var module_cone_angle := card.pattern.cone_half_angle if card.pattern != null else 55.0
		if not host.board.push.modules.is_pos_in_module_cone(target["pos"], pos, host.w(card.cast_range_cells()), module_cone_angle):
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	var obs: Dictionary = host.board.obstacles.module_at(pos)
	if obs.is_empty() and card.card_type == CardActionLine.TYPE_BREAK:
		obs = host.board.obstacles.tree_at(pos)  # romper también tala árboles
	if obs.is_empty():
		return
	if host.board.obstacles.obstacle_gap(obs) > host.w(card.primary_range_cells()):
		host.emit_log("combat.log.module.target_too_far")
		return
	target = obs
	if card.card_type == CardActionLine.TYPE_MODULE_THROW:
		phase = 1
		host.board.selection.actions.modes.actions.start_module_throw_target(host.w(card.cast_range_cells()))
		host.emit_log("combat.log.module.select_throw_landing")
		return
	if card.card_type == CardActionLine.TYPE_MODULE_PUSH:
		phase = 1
		var module_preview_angle := card.pattern.cone_half_angle if card.pattern != null else 55.0
		host.board.push.modules.start_module_push_cone(obs["pos"], host.w(card.cast_range_cells()), module_preview_angle)
		host.emit_log("combat.log.module.select_push_direction")
		return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	var flow := _flow()
	if not _flow_is_active(flow):
		return
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var obs := target
	_spend_card()
	host.hand_refresh_requested.emit()
	host.board.actors.presentation.play_player_animation("attack")
	await host.board.player_anim_finished
	if not _flow_is_active(flow):
		return
	host.board.actors.presentation.play_player_animation("idle")
	match played_card.card_type:
		CardActionLine.TYPE_BREAK:
			await _casts.cast_break(played_card, obs, flow)
		CardActionLine.TYPE_BUILD:
			_casts.cast_build(played_card, cell)
		CardActionLine.TYPE_MODULE_PUSH:
			await _casts.cast_module_push(played_card, obs, cell, flow)
		CardActionLine.TYPE_MODULE_THROW:
			await _casts.cast_module_throw(played_card, obs, cell, flow)
		CardActionLine.TYPE_COLLAPSE:
			await _casts.cast_collapse(played_card, flow)
	if not _flow_is_active(flow):
		return
	_finish()

func clear() -> void:
	index = -1
	phase = 0
	card = null
	target = {}
	host.board.selection.actions.modes.actions.clear_module_selection()
