class_name TreeSystem
extends Node3D

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

## Árboles: se pueden trepar (tree_climb), talar (cae y queda un tronco
## tirado) o prender fuego (arde TREE_BURN_ROUNDS y desaparece). Si el
## jugador está arriba cuando pasa algo de eso, cae al pie del árbol.
##
## Vive como hijo de MapArea, que se asigna a sí mismo en `map` antes de
## agregarlo al árbol (ver MapArea._init()) — lo necesita para la lista de
## obstáculos compartida (solid_obstacles), las mallas compartidas (make_disc,
## build_tile_disc), el movimiento del jugador (can_blink_to,
## blink_player_to, update_actor_positions), la señal
## player_knocked_off_tree, y la caché de bloqueos (obstacles_changed).
##
## ModuleSystem la referencia a su vez (ver ModuleSystem.tree_system): un
## módulo que choca contra un árbol al deslizarse (slide_module) tira al
## jugador si estaba trepado ahí — es la única dependencia cruzada real entre
## los dos sistemas de obstáculos.

## Asignado por MapArea antes de add_child(self) — ver MapArea._init().
var map: MapArea

const TREE_BURN_ROUNDS := 2
## El tronco tirado: tramos en fila, bajos (bloquean el paso, no la vista).
const LOG_SEGMENTS := 3
const LOG_SEGMENT_RADIUS := 0.45
## Hasta dónde llega el fuego de un árbol a los charcos de alrededor.
const TREE_FIRE_SPREAD_MARGIN := 0.5
## Charco de planta pegado a un árbol: sale así de más grande.
const TREE_VINE_RADIUS_MULT := 1.5
const TREE_VINE_REACH := 1.0

var _climbed_tree: Dictionary = {}
var _tree_landing_marker: MeshInstance3D
var _next_log_id := 0


## Arma el tronco + la copa de un árbol inicial (los que ya están en
## solid_obstacles al arrancar el combate). Llamado por MapArea._setup_obstacles().
func build_initial_tree_mesh(mi: MeshInstance3D, obs: Dictionary, pos: Vector2) -> void:
	var r: float = obs["radius"]
	var trunk := CylinderMesh.new()
	trunk.top_radius = r * 0.45
	trunk.bottom_radius = r * 0.6
	trunk.height = map.TREE_HEIGHT
	mi.mesh = trunk
	mi.position = Vector3(pos.x, map.TREE_HEIGHT * 0.5, pos.y)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.24, 0.14)
	mi.material_override = trunk_mat
	var canopy := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r * 2.2
	sphere.height = r * 3.2
	canopy.mesh = sphere
	canopy.position = Vector3(0.0, map.TREE_HEIGHT * 0.5, 0.0)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.18, 0.45, 0.2)
	canopy.material_override = leaf_mat
	mi.add_child(canopy)
	obs["canopy"] = canopy


## El árbol bajo `pos` (o {} si no hay).
func get_tree_at(pos: Vector2) -> Dictionary:
	for obs in map.terrain.obstacles():
		if CombatObstacle.type_of(obs) == CombatObstacle.TREE and CombatMapQueries.obstacle_edge_distance(obs, pos) <= map.CLICK_MARGIN:
			return obs
	return {}

static func is_tree_burning(tree: Dictionary) -> bool:
	return tree.get("burning", 0) > 0

## Dónde se puede caer desde el árbol: un lugar libre, o encima del enemigo.
func can_drop_at(pos: Vector2) -> bool:
	return map.interactions.can_blink_to(pos) or map.interactions.is_enemy_in_circle(pos, 0.0)

## Sube al árbol y marca dónde va a caer.
func climb_tree(tree: Dictionary, landing: Vector2) -> void:
	_climbed_tree = tree
	if _tree_landing_marker == null:
		_tree_landing_marker = map.presentation.make_disc(Color(0.3, 0.9, 0.4, 0.5))
	map.presentation.build_tile_disc(_tree_landing_marker, landing, 0.6, 0.0, map.HIGHLIGHT_Y)
	_tree_landing_marker.visible = true
	map.update_actor_positions()

## Cae del árbol a `landing` (si cae sobre el enemigo, queda pegado a él).
## Devuelve si le cayó encima.
func drop_from_tree(landing: Vector2) -> bool:
	var hit: bool = map.interactions.is_enemy_in_circle(landing, 0.0)
	var target := landing
	if hit:
		var away: Vector2 = landing - map.enemy_pos
		if away.length() < 0.001:
			away = map.player_pos - map.enemy_pos
		target = map.enemy_pos + (away.normalized() if away.length() > 0.001 else Vector2.RIGHT) * map.MIN_SEPARATION
		if not map.interactions.can_blink_to(target):
			target = map.player_pos  # sin lugar al lado del enemigo: cae al pie del árbol
	elif not map.interactions.can_blink_to(target):
		target = map.player_pos
	_leave_tree()
	map.interactions.blink_player_to(target)
	return hit

func is_player_in_tree() -> bool:
	return not _climbed_tree.is_empty()

func climbed_tree_position() -> Vector2:
	return _climbed_tree.get("pos", Vector2.ZERO)

func _leave_tree() -> void:
	_climbed_tree = {}
	if _tree_landing_marker != null:
		_tree_landing_marker.visible = false
	map.update_actor_positions()

## Si el jugador está en ese árbol, lo baja al pie y avisa
## (`player_knocked_off_tree`). Lo usan tanto la tala como otros sistemas que
## golpean un árbol, por eso es parte de la API pública de TreeSystem.
func knock_player_off(tree: Dictionary, burning: bool) -> void:
	if not is_same(_climbed_tree, tree):
		return
	_leave_tree()
	map.player_knocked_off_tree.emit(burning)

## Tala el árbol: cae hacia `dir` y queda un tronco tirado. Los tramos que
## caerían encima de alguien no se crean; si es el enemigo, le pega.
## Devuelve {"enemy_hit": bool}. Si el jugador estaba arriba, se cae.
func fell_tree(tree: Dictionary, dir: Vector2) -> Dictionary:
	knock_player_off(tree, false)
	var base: Vector2 = tree["pos"]
	var node = tree.get("node")
	if is_instance_valid(node):
		node.queue_free()
	map.terrain.remove_obstacle(tree)
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var log_id := _next_log_id
	_next_log_id += 1
	var enemy_hit := false
	var step := LOG_SEGMENT_RADIUS * 2.0
	for i in LOG_SEGMENTS:
		var p: Vector2 = base + dir * (step * float(i))
		if map.interactions.is_enemy_in_circle(p, LOG_SEGMENT_RADIUS):
			enemy_hit = true
			continue
		if map.interactions.is_player_in_circle(p, LOG_SEGMENT_RADIUS):
			continue
		if not map.terrain.is_inside_bounds(p):
			continue
		_add_log_segment(p, dir, log_id)
	map.obstacles_changed()
	return {"enemy_hit": enemy_hit}

func _add_log_segment(p: Vector2, dir: Vector2, log_id: int) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = LOG_SEGMENT_RADIUS * 0.8
	cyl.bottom_radius = LOG_SEGMENT_RADIUS * 0.8
	cyl.height = LOG_SEGMENT_RADIUS * 2.1
	mi.mesh = cyl
	mi.position = Vector3(p.x, LOG_SEGMENT_RADIUS * 0.8, p.y)
	mi.rotation = Vector3(0.0, -atan2(dir.y, dir.x), PI * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.24, 0.14)
	mi.material_override = mat
	map.add_child(mi)
	map.terrain.add_obstacle({
		"pos": p, "radius": LOG_SEGMENT_RADIUS, "type": CombatObstacle.ROCK, "module": true,
		"log_id": log_id, "node": mi,
	})

## Prende fuego los árboles que toca el círculo. Devuelve cuántos.
func ignite_trees_in_circle(center: Vector2, radius: float) -> int:
	var count := 0
	for obs in map.terrain.obstacle_snapshot():
		if CombatObstacle.type_of(obs) == CombatObstacle.TREE and CombatMapQueries.obstacle_edge_distance(obs, center) <= radius:
			count += int(_ignite_tree(obs))
	return count

## Prende fuego los árboles dentro del cono (Aliento). Devuelve cuántos.
func ignite_trees_in_cone(origin: Vector2, dir: Vector2, cone_range: float, half_angle_deg: float) -> int:
	var count := 0
	for obs in map.terrain.obstacle_snapshot():
		if CombatObstacle.type_of(obs) != CombatObstacle.TREE:
			continue
		var to_tree: Vector2 = obs["pos"] - origin
		var dist := to_tree.length()
		if dist > cone_range + float(obs["radius"]) or dist < 0.001:
			continue
		var slack := asin(clampf(float(obs["radius"]) / dist, 0.0, 1.0))
		if absf(dir.normalized().angle_to(to_tree)) <= deg_to_rad(half_angle_deg) + slack:
			count += int(_ignite_tree(obs))
	return count

func _ignite_tree(tree: Dictionary) -> bool:
	if is_tree_burning(tree):
		return false
	tree["burning"] = TREE_BURN_ROUNDS
	_paint_canopy(tree, true)
	knock_player_off(tree, true)
	_spread_fire_from_tree(tree)
	return true

## Un árbol en llamas prende los charcos de grasa y planta que lo tocan (y
## esos charcos, a su vez, los árboles que toquen: el fuego se propaga).
func _spread_fire_from_tree(tree: Dictionary) -> void:
	map.interactions.convert_puddles(tree["pos"], float(tree["radius"]) + TREE_FIRE_SPREAD_MARGIN, ["grease", "vine"], "fire")

## Apaga los árboles en llamas que toca el círculo (hielo, agua). Devuelve cuántos.
func extinguish_trees_in_circle(center: Vector2, radius: float) -> int:
	var count := 0
	for obs in map.terrain.obstacles():
		if CombatObstacle.type_of(obs) == CombatObstacle.TREE and is_tree_burning(obs) and CombatMapQueries.obstacle_edge_distance(obs, center) <= radius:
			obs["burning"] = 0
			_paint_canopy(obs, false)
			count += 1
	return count

func _paint_canopy(tree: Dictionary, burning: bool) -> void:
	var canopy = tree.get("canopy")
	if not is_instance_valid(canopy):
		return
	var mat := StandardMaterial3D.new()
	if burning:
		mat.albedo_color = Color(1.0, 0.4, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.0)
	else:
		mat.albedo_color = Color(0.18, 0.45, 0.2)
	canopy.material_override = mat

## Hay un árbol (que no arde) a `reach` o menos de `pos` (Raíces, charcos de planta).
func is_tree_near(pos: Vector2, reach: float) -> bool:
	for obs in map.terrain.obstacles():
		if CombatObstacle.type_of(obs) == CombatObstacle.TREE and not is_tree_burning(obs) and CombatMapQueries.obstacle_edge_distance(obs, pos) <= reach:
			return true
	return false

## Pararrayos: el primer árbol que cruza el segmento, con la fracción donde lo
## toca: {"tree": Dictionary, "t": float} o {} si no cruza ninguno.
func first_tree_on_segment(from: Vector2, to: Vector2) -> Dictionary:
	var best := {}
	for obs in map.terrain.obstacles():
		if CombatObstacle.type_of(obs) != CombatObstacle.TREE:
			continue
		var t := CombatMapQueries.first_contact_circle(from, to, obs["pos"], float(obs["radius"]))
		if t >= 0.0 and (best.is_empty() or t < best["t"]):
			best = {"tree": obs, "t": t}
	return best

func is_player_in_this_tree(tree: Dictionary) -> bool:
	return is_same(_climbed_tree, tree)

## Pasa una ronda: los árboles que arden se consumen y desaparecen.
func tick_trees() -> void:
	var changed := false
	for obs in map.terrain.obstacle_snapshot():
		if not is_tree_burning(obs):
			continue
		_spread_fire_from_tree(obs)
		obs["burning"] -= 1
		if obs["burning"] <= 0:
			var node = obs.get("node")
			if is_instance_valid(node):
				node.queue_free()
			map.terrain.remove_obstacle(obs)
			changed = true
	if changed:
		map.obstacles_changed()
