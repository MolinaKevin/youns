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
		host.map_area.start_collapse_selection(host._w(card.primary_range_cells()))
	else:
		host.map_area.start_module_selection(host._w(card.primary_range_cells()))
	match card.card_type:
		CardActionLine.TYPE_BREAK: host.log_requested.emit("Elegí el módulo que querés romper.")
		CardActionLine.TYPE_MODULE_PUSH: host.log_requested.emit("Elegí el módulo que querés golpear.")
		CardActionLine.TYPE_BUILD: host.log_requested.emit("Elegí dónde levantar el muro.")
		CardActionLine.TYPE_MODULE_THROW: host.log_requested.emit("Elegí el módulo que querés levantar.")
		CardActionLine.TYPE_COLLAPSE: host.log_requested.emit("Elegí al enemigo: los módulos pegados a él se le caen encima.")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_BUILD:
		if host.map_area.movement_distance(host.map_area.player_pos, pos) > host._w(card.primary_range_cells()):
			host.log_requested.emit("Demasiado lejos para levantar el muro ahí.")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if card.card_type == CardActionLine.TYPE_COLLAPSE:
		if not host.map_area.is_click_on_enemy(pos):
			return
		if not host.map_area.is_enemy_in_attack_range(host._w(card.primary_range_cells())):
			host.log_requested.emit("El enemigo está demasiado lejos.")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if phase == 1 and card.card_type == CardActionLine.TYPE_MODULE_THROW:
		# Lanzar: elegir dónde cae.
		if host.map_area.movement_distance(host.map_area.player_pos, pos) > host._w(card.cast_range_cells()):
			host.log_requested.emit("No llegás a tirarlo tan lejos.")
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	if phase == 1:
		# Golpe: elegir la dirección dentro del cono.
		var module_cone_angle := card.pattern.cone_half_angle if card.pattern != null else 55.0
		if not host.map_area.is_pos_in_module_cone(target["pos"], pos, host._w(card.cast_range_cells()), module_cone_angle):
			return
		host.pending_cell = pos
		host.confirm_popup_show_requested.emit(false)
		return
	var obs: Dictionary = host.map_area.get_module_at(pos)
	if obs.is_empty() and card.card_type == CardActionLine.TYPE_BREAK:
		obs = host.map_area.get_tree_at(pos)  # romper también tala árboles
	if obs.is_empty():
		return
	if host.map_area.obstacle_gap(obs) > host._w(card.primary_range_cells()):
		host.log_requested.emit("Demasiado lejos para alcanzar eso.")
		return
	target = obs
	if card.card_type == CardActionLine.TYPE_MODULE_THROW:
		phase = 1
		host.map_area.start_module_throw_target(host._w(card.cast_range_cells()))
		host.log_requested.emit("Elegí dónde tirarlo.")
		return
	if card.card_type == CardActionLine.TYPE_MODULE_PUSH:
		phase = 1
		var module_preview_angle := card.pattern.cone_half_angle if card.pattern != null else 55.0
		host.map_area.start_module_push_cone(obs["pos"], host._w(card.cast_range_cells()), module_preview_angle)
		host.log_requested.emit("Elegí hacia dónde mandar el módulo.")
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
	host.map_area.play_player_anim("attack")
	await host.map_area.player_anim_finished
	host.map_area.play_player_anim("idle")
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
	host.map_area.clear_module_selection()
