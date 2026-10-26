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
		host.map_area.interactions.start_collapse_selection(host.w(card.primary_range_cells()))
	else:
		host.map_area.interactions.start_module_selection(host.w(card.primary_range_cells()))
	match card.card_type:
		CardActionLine.TYPE_BREAK: host.emit_log("combat.log.module.select_break")
		CardActionLine.TYPE_MODULE_PUSH: host.emit_log("combat.log.module.select_push")
		CardActionLine.TYPE_BUILD: host.emit_log("combat.log.module.select_build")
		CardActionLine.TYPE_MODULE_THROW: host.emit_log("combat.log.module.select_throw")
		CardActionLine.TYPE_COLLAPSE: host.emit_log("combat.log.module.select_collapse")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_BUILD:
		if host.map_area.queries.movement_distance(host.map_area.player_pos, pos) > host.w(card.primary_range_cells()):
			host.emit_log("combat.log.module.build_too_far")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if card.card_type == CardActionLine.TYPE_COLLAPSE:
		if not host.map_area.interactions.is_click_on_enemy(pos):
			return
		if not host.map_area.queries.is_enemy_in_attack_range(host.w(card.primary_range_cells())):
			host.emit_log("combat.log.module.enemy_too_far")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if phase == 1 and card.card_type == CardActionLine.TYPE_MODULE_THROW:
		# Lanzar: elegir dónde cae.
		if host.map_area.queries.movement_distance(host.map_area.player_pos, pos) > host.w(card.cast_range_cells()):
			host.emit_log("combat.log.module.throw_too_far")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if phase == 1:
		# Golpe: elegir la dirección dentro del cono.
		var module_cone_angle := card.pattern.cone_half_angle if card.pattern != null else 55.0
		if not host.map_area.interactions.is_pos_in_module_cone(target["pos"], pos, host.w(card.cast_range_cells()), module_cone_angle):
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	var obs: Dictionary = host.map_area.interactions.module_at(pos)
	if obs.is_empty() and card.card_type == CardActionLine.TYPE_BREAK:
		obs = host.map_area.interactions.tree_at(pos)  # romper también tala árboles
	if obs.is_empty():
		return
	if host.map_area.interactions.obstacle_gap(obs) > host.w(card.primary_range_cells()):
		host.emit_log("combat.log.module.target_too_far")
		return
	target = obs
	if card.card_type == CardActionLine.TYPE_MODULE_THROW:
		phase = 1
		host.map_area.interactions.start_module_throw_target(host.w(card.cast_range_cells()))
		host.emit_log("combat.log.module.select_throw_landing")
		return
	if card.card_type == CardActionLine.TYPE_MODULE_PUSH:
		phase = 1
		var module_preview_angle := card.pattern.cone_half_angle if card.pattern != null else 55.0
		host.map_area.interactions.start_module_push_cone(obs["pos"], host.w(card.cast_range_cells()), module_preview_angle)
		host.emit_log("combat.log.module.select_push_direction")
		return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var obs := target
	_spend_card()
	host.hand_refresh_requested.emit()
	host.map_area.actors.play_player_animation("attack")
	await host.map_area.player_anim_finished
	host.map_area.actors.play_player_animation("idle")
	match played_card.card_type:
		CardActionLine.TYPE_BREAK:
			await _casts.cast_break(played_card, obs)
		CardActionLine.TYPE_BUILD:
			_casts.cast_build(played_card, cell)
		CardActionLine.TYPE_MODULE_PUSH:
			await _casts.cast_module_push(played_card, obs, cell)
		CardActionLine.TYPE_MODULE_THROW:
			await _casts.cast_module_throw(played_card, obs, cell)
		CardActionLine.TYPE_COLLAPSE:
			await _casts.cast_collapse(played_card)
	_finish()

func clear() -> void:
	index = -1
	phase = 0
	card = null
	target = {}
	host.map_area.interactions.clear_module_selection()
