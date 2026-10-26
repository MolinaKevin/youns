class_name TechTreeLayout
extends RefCounted

## Calcula las capas (camino más largo desde la raíz) y las posiciones de un
## árbol de recetas del laboratorio, a partir de sus dependencias
## (desbloqueos directos vía reward y ingredientes producidos por otra
## receta). No sabe nada de Control ni de nodos — tech_tree_view.gd sólo
## instancia los Panels a partir de esto.

const LabReward := preload("res://data/lab_reward.gd")

const NODE_W := 150.0
const NODE_H := 55.0
const H_GAP := 70.0
const V_GAP := 14.0

var positions: Dictionary = {}  # recipe_id -> Vector2
var edges: Array = []  # [[from: Vector2, to: Vector2], ...]
var canvas_size := Vector2.ZERO

func _init(recipes: Array) -> void:
	if recipes.is_empty():
		return
	var parents := _compute_parents(recipes)
	var layers := _compute_layers(recipes, parents)
	var by_layer := _group_by_layer(recipes, layers)
	_compute_positions(by_layer)
	_compute_edges(recipes, parents)
	_compute_canvas_size()

## recipe_id -> [parent_ids]: desbloqueos directos vía reward, más la receta
## que produce cada ingrediente que necesita.
func _compute_parents(recipes: Array) -> Dictionary:
	var producers: Dictionary = {}  # item_id -> recipe_id que lo produce
	for r in recipes:
		for reward in ([r.reward] + r.extra_rewards):
			if LabReward.type_of(reward) == LabReward.ITEM:
				producers[reward["id"]] = r.id

	var parents: Dictionary = {}
	for r in recipes:
		parents[r.id] = []

	for r in recipes:
		for reward in ([r.reward] + r.extra_rewards):
			if LabReward.type_of(reward) == LabReward.UNLOCK_RECIPE:
				var child_id: String = reward["id"]
				if parents.has(child_id) and not parents[child_id].has(r.id):
					parents[child_id].append(r.id)
		for ing in r.ingredients:
			var prod_id: String = producers.get(ing["id"], "")
			if prod_id != "" and prod_id != r.id and not parents[r.id].has(prod_id):
				parents[r.id].append(prod_id)
	return parents

func _compute_layers(recipes: Array, parents: Dictionary) -> Dictionary:
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
	return layers

func _group_by_layer(recipes: Array, layers: Dictionary) -> Dictionary:
	var by_layer: Dictionary = {}
	for r in recipes:
		var l: int = layers[r.id]
		if not by_layer.has(l):
			by_layer[l] = []
		by_layer[l].append(r.id)
	return by_layer

func _compute_positions(by_layer: Dictionary) -> void:
	for layer_idx in by_layer:
		var ids: Array = by_layer[layer_idx]
		var x: float = 16.0 + layer_idx * (NODE_W + H_GAP)
		for i in ids.size():
			var y := 16.0 + i * (NODE_H + V_GAP)
			positions[ids[i]] = Vector2(x, y)

func _compute_edges(recipes: Array, parents: Dictionary) -> void:
	for r in recipes:
		for pid in parents[r.id]:
			if positions.has(pid) and positions.has(r.id):
				edges.append([
					positions[pid] + Vector2(NODE_W, NODE_H * 0.5),
					positions[r.id] + Vector2(0.0, NODE_H * 0.5)
				])

func _compute_canvas_size() -> void:
	var max_x := 0.0
	var max_y := 0.0
	for pos in positions.values():
		max_x = maxf(max_x, pos.x + NODE_W + 16.0)
		max_y = maxf(max_y, pos.y + NODE_H + 16.0)
	canvas_size = Vector2(max_x, max_y)
