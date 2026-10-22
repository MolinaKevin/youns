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
			host.map_area.start_overwatch_selection(host._w(card.cast_range_cells()), CombatPlayerActions.BOLT_HALF_ANGLE)
			host.log_requested.emit("Elegí hacia dónde tirar el rayo.")
		CardActionLine.TYPE_CONE_BLAST:
			host.map_area.start_overwatch_selection(host._w(card.cast_range_cells()), card.pattern.cone_half_angle if card.pattern != null else CombatPlayerActions.CONE_HALF_ANGLE)
			host.log_requested.emit("Elegí hacia dónde soplar.")
		CardActionLine.TYPE_CURSE:
			host.map_area.start_push_enemy_selection(host._w(card.cast_range_cells()))
			host.log_requested.emit("Elegí al enemigo.")
		CardActionLine.TYPE_PUDDLE_HOP:
			host.map_area.start_spell_selection(host._w(card.cast_range_cells()))
			host.log_requested.emit("Elegí el charco que querés trasladar.")
		CardActionLine.TYPE_TREE_CLIMB:
			host.map_area.start_module_selection(host._w(card.primary_range_cells()))
			host.log_requested.emit("Elegí el árbol al que querés trepar.")
		_:
			host.map_area.start_spell_selection(host._w(card.cast_range_cells()))
			host.log_requested.emit("Elegí el punto.")

func on_tile_selected(pos: Vector2) -> void:
	if card.card_type == CardActionLine.TYPE_TREE_CLIMB:
		_on_tree_climb_click(pos)
		return
	if card.card_type == CardActionLine.TYPE_PUDDLE_HOP and puddle.is_empty():
		var zone: Dictionary = host.map_area.get_puddle_at(pos)
		if zone.is_empty():
			return
		var gap: float = host.map_area.movement_distance(host.map_area.player_pos, zone["pos"]) - float(zone["radius"])
		if gap > host._w(card.cast_range_cells()):
			host.log_requested.emit("Ese charco está demasiado lejos.")
			return
		puddle = zone
		host.map_area.start_puddle_hop_landing(zone["pos"], host._w(card.primary_range_cells()))
		host.log_requested.emit("Elegí dónde cae el charco.")
		return
	match card.card_type:
		CardActionLine.TYPE_PUDDLE_HOP:
			if host.map_area.movement_distance(puddle["pos"], pos) > host._w(card.primary_range_cells()):
				host.log_requested.emit("No llega tan lejos desde ese charco.")
				return
			if pos.x < 0.0 or pos.y < 0.0 or pos.x > host.map_area.WORLD_W or pos.y > host.map_area.WORLD_H:
				return
		CardActionLine.TYPE_CHAIN_BOLT, CardActionLine.TYPE_CONE_BLAST:
			var new_dir: Vector2 = pos - host.map_area.player_pos
			if new_dir.length() < 0.2:
				return
			dir = new_dir.normalized()
		CardActionLine.TYPE_CURSE:
			if not host.map_area.is_click_on_enemy(pos):
				return
			if not host.map_area.is_enemy_in_attack_range(host._w(card.cast_range_cells())):
				host.log_requested.emit("El enemigo está demasiado lejos.")
				return
			if not host.map_area.has_line_of_sight(host.map_area.player_pos, host.map_area.enemy_pos):
				host.log_requested.emit("No ves al enemigo desde acá.")
				return
		_:
			if host.map_area.movement_distance(host.map_area.player_pos, pos) > host._w(card.cast_range_cells()):
				host.log_requested.emit("Demasiado lejos.")
				return
			# El meteoro cae del cielo; el resto necesita ver el punto.
			if card.card_type == CardActionLine.TYPE_ELEMENT_BOLT and not host.map_area.has_line_of_sight(host.map_area.player_pos, pos):
				host.log_requested.emit("Hay algo en el medio.")
				return
			if card.card_type == CardActionLine.TYPE_BLINK and not host.map_area.can_blink_to(pos):
				host.log_requested.emit("No podés aparecer ahí.")
				return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

## Trepar árbol: primero el árbol (pegado a vos), después dónde caer (dentro
## del rango alrededor del árbol: un lugar libre o encima del enemigo).
func _on_tree_climb_click(pos: Vector2) -> void:
	if tree.is_empty():
		var found: Dictionary = host.map_area.get_tree_at(pos)
		if found.is_empty():
			return
		if host.map_area.obstacle_gap(found) > host._w(card.primary_range_cells()):
			host.log_requested.emit("Tenés que estar pegado al árbol para trepar.")
			return
		if host.map_area.is_tree_burning(found):
			host.log_requested.emit("Ese árbol está en llamas: no podés trepar.")
			return
		tree = found
		host.map_area.start_puddle_hop_landing(tree["pos"], host._w(card.cast_range_cells()))
		host.log_requested.emit("Elegí dónde vas a caer al final de la ronda.")
		return
	if host.map_area.movement_distance(tree["pos"], pos) > host._w(card.cast_range_cells()):
		host.log_requested.emit("No llegás a caer tan lejos.")
		return
	if not host.map_area.can_drop_at(pos):
		host.log_requested.emit("No podés caer ahí.")
		return
	host.pending_cell = pos
	host.confirm_popup_show_requested.emit(false)

func execute(cell: Vector2) -> void:
	if not _index_valid():
		clear()
		return
	var played_card: CardActionLine = host.state.turn_actions[index]
	var saved_dir := dir
	var saved_puddle := puddle
	var saved_tree := tree
	_spend_card()
	host.hand_refresh_requested.emit()
	if not played_card.card_type in [CardActionLine.TYPE_BLINK, CardActionLine.TYPE_DELAYED_AREA, CardActionLine.TYPE_TREE_CLIMB]:
		host.map_area.play_player_anim("range")
		await host.map_area.player_anim_finished
		host.map_area.play_player_anim("idle")
	match played_card.card_type:
		CardActionLine.TYPE_ELEMENT_BOLT:
			await _casts.cast_element_bolt(played_card, cell)
		CardActionLine.TYPE_CHAIN_BOLT:
			await _casts.cast_chain_bolt(played_card, saved_dir)
		CardActionLine.TYPE_DELAYED_AREA:
			_casts.cast_delayed_area(played_card, cell)
		CardActionLine.TYPE_CONE_BLAST:
			await _casts.cast_cone_blast(played_card, saved_dir)
		CardActionLine.TYPE_CURSE:
			await _casts.cast_curse(played_card)
		CardActionLine.TYPE_BLINK:
			_casts.cast_blink(played_card, cell)
		CardActionLine.TYPE_PUDDLE_HOP:
			await _casts.cast_puddle_hop(played_card, saved_puddle, cell)
		CardActionLine.TYPE_TREE_CLIMB:
			_casts.cast_tree_climb(played_card, saved_tree, cell)
	_finish()
	host.map_area.clear_card_pattern_preview()

func clear() -> void:
	index = -1
	card = null
	dir = Vector2.ZERO
	puddle = {}
	tree = {}
	host.map_area.clear_spell_selection()
	host.map_area.clear_push_selection()
