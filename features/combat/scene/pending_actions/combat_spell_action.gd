class_name CombatSpellAction
extends CombatPendingAction

## element_bolt, chain_bolt, delayed_area, cone_blast, curse, blink,
## puddle_hop y tree_climb. Cada subtipo apunta distinto (punto, dirección,
## al enemigo) y algunos son de dos pasos (puddle_hop: elegir el charco y
## después dónde cae; tree_climb: elegir el árbol y después dónde caer).
## Esta clase solo resuelve ESO — la selección en el mapa. El efecto de cada
## hechizo una vez confirmado el punto/dirección/objetivo vive en
## CombatSpellCasts (combat_spell_casts.gd).

var dir: Vector2 = Vector2.ZERO
## Traslado de charco: el charco elegido en el primer paso.
var puddle: Dictionary = {}
## Trepar árbol: el árbol elegido en el primer paso (usa el mismo flujo).
var tree: Dictionary = {}

var _casts: CombatSpellCasts

func _init(p_host: CombatPlayerActions) -> void:
	super._init(p_host)
	_casts = CombatSpellCasts.new(p_host)

func start(p_index: int, p_card: CardActionLine) -> void:
	index = p_index
	card = p_card
	dir = Vector2.ZERO
	puddle = {}
	tree = {}
	match card.card_type:
		CardActionLine.TYPE_CHAIN_BOLT:
			host.board.selection.actions.overwatch.start_overwatch_selection(host.w(card.cast_range_cells()), CombatPlayerActions.BOLT_HALF_ANGLE)
			host.emit_log("combat.log.spell.select_bolt_direction")
		CardActionLine.TYPE_CONE_BLAST:
			host.board.selection.actions.overwatch.start_overwatch_selection(host.w(card.cast_range_cells()), card.pattern.cone_half_angle if card.pattern != null else CombatPlayerActions.CONE_HALF_ANGLE)
			host.emit_log("combat.log.spell.select_cone_direction")
		CardActionLine.TYPE_CURSE:
			host.board.push.selection.start_push_enemy_selection(host.w(card.cast_range_cells()))
			host.emit_log("combat.log.spell.select_enemy")
		CardActionLine.TYPE_PUDDLE_HOP:
			host.board.selection.actions.modes.actions.start_spell_selection(host.w(card.cast_range_cells()))
			host.emit_log("combat.log.spell.select_puddle")
		CardActionLine.TYPE_TREE_CLIMB:
			host.board.selection.actions.modes.actions.start_module_selection(host.w(card.primary_range_cells()))
			host.emit_log("combat.log.spell.select_tree")
		_:
			host.board.selection.actions.modes.actions.start_spell_selection(host.w(card.cast_range_cells()))
			host.emit_log("combat.log.spell.select_point")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_TREE_CLIMB:
		_on_tree_climb_click(pos)
		return
	if card.card_type == CardActionLine.TYPE_PUDDLE_HOP and puddle.is_empty():
		var zone: Dictionary = host.board.effects.puddle_port.queries.puddle_at(pos)
		if zone.is_empty():
			return
		var gap: float = host.board.queries.actors.movement_distance(host.board.state.player_position(), zone["pos"]) - float(zone["radius"])
		if gap > host.w(card.cast_range_cells()):
			host.emit_log("combat.log.spell.puddle_too_far")
			return
		puddle = zone
		host.board.selection.actions.modes.terrain.start_puddle_hop_landing(zone["pos"], host.w(card.primary_range_cells()))
		host.emit_log("combat.log.spell.select_puddle_landing")
		return
	match card.card_type:
		CardActionLine.TYPE_PUDDLE_HOP:
			if host.board.queries.actors.movement_distance(puddle["pos"], pos) > host.w(card.primary_range_cells()):
				host.emit_log("combat.log.spell.puddle_landing_too_far")
				return
			if pos.x < 0.0 or pos.y < 0.0 or pos.x > host.board.WORLD_W or pos.y > host.board.WORLD_H:
				return
		CardActionLine.TYPE_CHAIN_BOLT, CardActionLine.TYPE_CONE_BLAST:
			var new_dir: Vector2 = pos - host.board.state.player_position()
			if new_dir.length() < 0.2:
				return
			dir = new_dir.normalized()
		CardActionLine.TYPE_CURSE:
			if not host.board.selection.targeting.queries.is_click_on_enemy(pos):
				return
			if not host.board.queries.actors.is_enemy_in_attack_range(host.w(card.cast_range_cells())):
				host.emit_log("combat.log.spell.enemy_too_far")
				return
			if not host.board.queries.line_of_sight.has_line_of_sight(host.board.state.player_position(), host.board.state.enemy_position()):
				host.emit_log("combat.log.spell.enemy_no_line_of_sight")
				return
		_:
			if host.board.queries.actors.movement_distance(host.board.state.player_position(), pos) > host.w(card.cast_range_cells()):
				host.emit_log("combat.log.spell.point_too_far")
				return
			# El meteoro cae del cielo; el resto necesita ver el punto.
			if card.card_type == CardActionLine.TYPE_ELEMENT_BOLT and not host.board.queries.line_of_sight.has_line_of_sight(host.board.state.player_position(), pos):
				host.emit_log("combat.log.spell.point_blocked")
				return
			if card.card_type == CardActionLine.TYPE_BLINK and not host.board.terrain.geometry.collision.can_blink_to(pos):
				host.emit_log("combat.log.spell.blink_invalid_destination")
				return
	_request_confirm(pos)

## Trepar árbol: primero el árbol (pegado a vos), después dónde caer (dentro
## del rango alrededor del árbol: un lugar libre o encima del enemigo).
func _on_tree_climb_click(pos: Vector2) -> void:
	if tree.is_empty():
		var found: Dictionary = host.board.obstacles.tree_at(pos)
		if found.is_empty():
			return
		if host.board.obstacles.obstacle_gap(found) > host.w(card.primary_range_cells()):
			host.emit_log("combat.log.spell.tree_not_near")
			return
		if host.board.obstacles.is_tree_burning(found):
			host.emit_log("combat.log.spell.tree_burning")
			return
		tree = found
		host.board.selection.actions.modes.terrain.start_puddle_hop_landing(tree["pos"], host.w(card.cast_range_cells()))
		host.emit_log("combat.log.spell.select_tree_landing")
		return
	if host.board.queries.actors.movement_distance(tree["pos"], pos) > host.w(card.cast_range_cells()):
		host.emit_log("combat.log.spell.tree_landing_too_far")
		return
	if not host.board.obstacles.can_drop_at(pos):
		host.emit_log("combat.log.spell.tree_landing_invalid")
		return
	_request_confirm(pos)

func execute(cell: Vector2) -> void:
	var flow := _flow()
	if _should_abort_execute(flow):
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var saved_dir := dir
	var saved_puddle := puddle
	var saved_tree := tree
	_spend_card()
	host.hand_refresh_requested.emit()
	if not played_card.card_type in [CardActionLine.TYPE_BLINK, CardActionLine.TYPE_DELAYED_AREA, CardActionLine.TYPE_TREE_CLIMB]:
		host.board.actors.presentation.play_player_animation("range")
		await host.board.player_anim_finished
		if not _flow_is_active(flow):
			return
		host.board.actors.presentation.play_player_animation("idle")
	match played_card.card_type:
		CardActionLine.TYPE_ELEMENT_BOLT:
			await _casts.cast_element_bolt(played_card, cell, flow)
		CardActionLine.TYPE_CHAIN_BOLT:
			await _casts.cast_chain_bolt(played_card, saved_dir, flow)
		CardActionLine.TYPE_DELAYED_AREA:
			_casts.cast_delayed_area(played_card, cell)
		CardActionLine.TYPE_CONE_BLAST:
			await _casts.cast_cone_blast(played_card, saved_dir, flow)
		CardActionLine.TYPE_CURSE:
			await _casts.cast_curse(played_card, flow)
		CardActionLine.TYPE_BLINK:
			_casts.cast_blink(played_card, cell)
		CardActionLine.TYPE_PUDDLE_HOP:
			await _casts.cast_puddle_hop(played_card, saved_puddle, cell, flow)
		CardActionLine.TYPE_TREE_CLIMB:
			_casts.cast_tree_climb(played_card, saved_tree, cell)
	if not _flow_is_active(flow):
		return
	_finish()
	host.board.presentation.patterns.clear_card_pattern()

func clear() -> void:
	index = -1
	card = null
	dir = Vector2.ZERO
	puddle = {}
	tree = {}
	host.board.selection.actions.modes.actions.clear_spell_selection()
	host.board.push.clear_push_selection()
