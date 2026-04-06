extends Control

const NODE_W := 150.0
const NODE_H := 55.0
const H_GAP := 70.0
const V_GAP := 14.0

var _edges: Array = []
var _positions: Dictionary = {}  # recipe_id -> Vector2

func _ready() -> void:
	LaboratoryState.recipes_loaded.connect(_build)
	LaboratoryState.recipe_unlocked.connect(func(_r): _build())
	if LaboratoryState.all_recipes.size() > 0:
		_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	_edges.clear()
	_positions.clear()

	var recipes := LaboratoryState.all_recipes.filter(
		func(r): return LaboratoryState.is_recipe_unlocked(r.id) or LaboratoryState.is_recipe_completed(r.id)
	)
	if recipes.is_empty():
		return

	# item_id -> recipe_id que lo produce
	var producers: Dictionary = {}
	for r in recipes:
		for reward in ([r.reward] + r.extra_rewards):
			if reward.get("type") == "item":
				producers[reward["id"]] = r.id

	# recipe_id -> [parent_ids]
	var parents: Dictionary = {}
	for r in recipes:
		parents[r.id] = []

	for r in recipes:
		# desbloqueos directos via rewards
		for reward in ([r.reward] + r.extra_rewards):
			if reward.get("type") == "unlock_recipe":
				var child_id: String = reward["id"]
				if parents.has(child_id) and not parents[child_id].has(r.id):
					parents[child_id].append(r.id)
		# dependencias por ingredientes
		for ing in r.ingredients:
			var prod_id: String = producers.get(ing["id"], "")
			if prod_id != "" and prod_id != r.id and not parents[r.id].has(prod_id):
				parents[r.id].append(prod_id)

	# Asignar capas (camino más largo desde raíz)
	var layers: Dictionary = {}
	for r in recipes:
		layers[r.id] = 0
	var changed := true
	while changed:
		changed = false
		for r in recipes:
			for pid in parents[r.id]:
				var new_l: int = layers.get(pid, 0) + 1
				if new_l > layers[r.id]:
					layers[r.id] = new_l
					changed = true

	# Agrupar por capa
	var by_layer: Dictionary = {}
	for r in recipes:
		var l: int = layers[r.id]
		if not by_layer.has(l):
			by_layer[l] = []
		by_layer[l].append(r.id)

	# Calcular posiciones
	for layer_idx in by_layer:
		var ids: Array = by_layer[layer_idx]
		var x: float = 16.0 + layer_idx * (NODE_W + H_GAP)
		for i in ids.size():
			var y := 16.0 + i * (NODE_H + V_GAP)
			_positions[ids[i]] = Vector2(x, y)

	# Aristas
	for r in recipes:
		for pid in parents[r.id]:
			if _positions.has(pid) and _positions.has(r.id):
				_edges.append([
					_positions[pid] + Vector2(NODE_W, NODE_H * 0.5),
					_positions[r.id] + Vector2(0.0, NODE_H * 0.5)
				])

	# Tamaño del canvas
	var max_x := 0.0
	var max_y := 0.0
	for pos in _positions.values():
		max_x = maxf(max_x, pos.x + NODE_W + 16.0)
		max_y = maxf(max_y, pos.y + NODE_H + 16.0)
	custom_minimum_size = Vector2(max_x, max_y)

	# Crear nodos
	for r in recipes:
		_create_node(r)

	queue_redraw()

func _create_node(recipe: Resource) -> void:
	var pos: Vector2 = _positions.get(recipe.id, Vector2.ZERO)

	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(NODE_W, NODE_H)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = recipe.recipe_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = recipe.action_type
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 10)
	match recipe.action_type:
		"upgrade":
			type_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"loop":
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		"instant":
			type_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(type_lbl)

	add_child(panel)

func _draw() -> void:
	for edge in _edges:
		draw_line(edge[0], edge[1], Color(0.65, 0.65, 0.65, 0.7), 1.5)
