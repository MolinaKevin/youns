class_name ModuleSystem
extends Node3D

const CombatObstacle := preload("res://features/combat/scene/combat_obstacle.gd")

## Los obstáculos que se pueden romper, golpear o crear son módulos: bloques
## de MODULE_SIZE × MODULE_SIZE (las piedras chicas del mapa también cuentan
## como uno, igual que los troncos que deja un árbol talado — ver
## TreeSystem.fell_tree). No tienen vida: una línea "break" los rompe de una.
##
## Vive como hijo de MapArea, que se asigna a sí mismo en `map` antes de
## agregarlo al árbol (ver MapArea._init()) — lo necesita para la lista de
## obstáculos compartida (solid_obstacles), las mallas y discos compartidos (_attack_disc,
## _push_disc, build_cone_disc), el empujón genérico (start_push_enemy_selection)
## y la caché de bloqueos (obstacles_changed).
##
## `tree_system` lo asigna también MapArea en _init(): un módulo que choca
## contra un árbol al deslizarse (slide_module) tira al jugador si estaba
## trepado ahí — la única dependencia cruzada real con TreeSystem.

## Asignados por MapArea antes de add_child(self) — ver MapArea._init().
var map: MapArea
var tree_system: TreeSystem

const MODULE_SIZE := 1.0
## Dos módulos están "pegados" (para romperlos juntos) si sus centros están a
## esta distancia o menos (incluye los de al lado en diagonal).
const MODULE_TOUCH_DISTANCE := MODULE_SIZE * 1.6
## Holgura para considerar que un módulo lanzado cae "encima" de alguien.
const MODULE_ADJACENT_MARGIN := 0.35
## Derrumbe: un módulo está pegado al enemigo si su borde queda a menos de un
## módulo de su huella. Así cuentan los vecinos del hueco que deja un muro que
## pasa por encima del enemigo (build_modules saltea los lugares ocupados).
const MODULE_COLLAPSE_MARGIN := MODULE_SIZE + 0.1

var _module_mat: StandardMaterial3D


## Arma el cilindro de una piedra inicial (las que ya están en solid_obstacles
## al arrancar el combate, con module:true). Llamado por MapArea._setup_obstacles().
func build_initial_rock_mesh(mi: MeshInstance3D, obs: Dictionary, pos: Vector2, rock_mat: StandardMaterial3D) -> void:
	var r: float      = obs["radius"]
	var cyl          := CylinderMesh.new()
	cyl.top_radius    = r * 0.70
	cyl.bottom_radius = r
	cyl.height        = r * 0.9
	mi.mesh           = cyl
	mi.position       = Vector3(pos.x, cyl.height * 0.5, pos.y)
	mi.material_override = rock_mat


static func is_module(obs: Dictionary) -> bool:
	return obs.get("module", false)

## Muestra el alcance (romper, golpear o crear) alrededor del jugador.
func start_module_selection(reach: float) -> void:
	map.presentation.show_player_range(reach + map.actors.player_radius())

func clear_module_selection() -> void:
	map.presentation.clear_module_selection()
	map.presentation.clear_enemy_highlight()

## Derrumbe: resalta al enemigo y el alcance.
func start_collapse_selection(reach: float) -> void:
	map.interactions.start_push_enemy_selection(reach)

## Lanzar módulo: muestra hasta dónde se puede tirar.
func start_module_throw_target(throw_range: float) -> void:
	map.presentation.show_player_range(throw_range)

## Módulos pegados al enemigo (los que le caen encima con un derrumbe).
func modules_adjacent_to_enemy() -> Array:
	var result: Array = []
	for obs in map.terrain.obstacles():
		if is_module(obs) and CombatMapQueries.obstacle_edge_distance(obs, map.enemy_pos) <= map.actors.enemy_radius() + MODULE_COLLAPSE_MARGIN:
			result.append(obs)
	return result

## Derrumbe: los módulos pegados al enemigo se le caen encima y se rompen.
## Devuelve cuántos fueron.
func collapse_modules_on_enemy() -> int:
	var fallen := modules_adjacent_to_enemy()
	for obs in fallen:
		_remove_module(obs)
	if not fallen.is_empty():
		map.obstacles_changed()
	return fallen.size()

## Lanza el módulo a `target` (vuela por encima de todo): al caer se rompe y le
## pega a quien esté ahí. Devuelve {"enemy": bool, "player": bool}.
func throw_module(obs: Dictionary, target: Vector2) -> Dictionary:
	var reach := MODULE_SIZE * 0.5 + MODULE_ADJACENT_MARGIN
	var hits := {
		"enemy": target.distance_to(map.enemy_pos) <= reach + map.actors.enemy_radius(),
		"player": target.distance_to(map.player_pos) <= reach + map.actors.player_radius(),
	}
	map.terrain.remove_obstacle(obs)
	map.obstacles_changed()
	var node = obs.get("node")
	if is_instance_valid(node):
		if node.is_inside_tree():
			var tween: Tween = node.create_tween()
			var mid := Vector3((node.position.x + target.x) * 0.5, 3.0, (node.position.z + target.y) * 0.5)
			tween.tween_property(node, "position", mid, 0.18)
			tween.tween_property(node, "position", Vector3(target.x, MODULE_SIZE * 0.5, target.y), 0.18)
			tween.tween_callback(node.queue_free)
		else:
			node.free()
	return hits

func _remove_module(obs: Dictionary) -> void:
	var node = obs.get("node")
	if is_instance_valid(node):
		node.queue_free()
	map.terrain.remove_obstacle(obs)

## El módulo bajo `pos` (o {} si no hay).
func get_module_at(pos: Vector2) -> Dictionary:
	for obs in map.terrain.obstacles():
		if is_module(obs) and CombatMapQueries.obstacle_edge_distance(obs, pos) <= map.CLICK_MARGIN:
			return obs
	return {}

## Distancia del jugador al borde del obstáculo, contando desde su huella.
func obstacle_gap(obs: Dictionary) -> float:
	return maxf(0.0, CombatMapQueries.obstacle_edge_distance(obs, map.player_pos) - map.actors.player_radius())

## Levanta hasta `count` módulos en fila, centrada en `center` y perpendicular
## a la línea jugador → center (un muro de frente). Los lugares ocupados (por
## un actor, otro obstáculo o fuera del mapa) se saltean. Devuelve cuántos creó.
func build_modules(center: Vector2, count: int) -> int:
	var dir: Vector2 = center - map.player_pos
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var built := 0
	for i in count:
		var p: Vector2 = center + perp * (float(i) - float(count - 1) * 0.5) * MODULE_SIZE
		if _module_fits(p):
			_add_module(p)
			built += 1
	if built > 0:
		map.obstacles_changed()
	return built

func _module_fits(p: Vector2) -> bool:
	var half := MODULE_SIZE * 0.5
	if not map.terrain.is_inside_bounds(p, half):
		return false
	if p.distance_to(map.player_pos) < map.actors.player_radius() + half:
		return false
	if p.distance_to(map.enemy_pos) < map.actors.enemy_radius() + half:
		return false
	for obs in map.terrain.obstacles():
		if CombatMapQueries.obstacle_edge_distance(obs, p) < half * 0.9:
			return false
	return true

func _add_module(p: Vector2) -> Dictionary:
	if _module_mat == null:
		_module_mat = StandardMaterial3D.new()
		_module_mat.albedo_color = Color(0.46, 0.42, 0.36)
		_module_mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(MODULE_SIZE, MODULE_SIZE, MODULE_SIZE)
	mi.mesh = box
	mi.position = Vector3(p.x, MODULE_SIZE * 0.5, p.y)
	mi.material_override = _module_mat
	map.add_child(mi)
	var obs := {"pos": p, "box": Vector2(MODULE_SIZE, MODULE_SIZE), "type": CombatObstacle.SOLID, "module": true, "node": mi}
	map.terrain.add_obstacle(obs)
	return obs

## Rompe `first` y los módulos pegados a él (los más cercanos primero), hasta
## `count` en total. Devuelve cuántos rompió.
func break_modules(first: Dictionary, count: int) -> int:
	var group: Array = [first]
	if first.has("log_id"):
		# Un tronco tirado se rompe entero, con una sola carta.
		group = map.terrain.obstacles().filter(func(o): return o.get("log_id", -1) == first["log_id"])
		count = 0
	while group.size() < count:
		var best: Dictionary = {}
		var best_dist := INF
		for obs in map.terrain.obstacles():
			if not is_module(obs) or group.any(func(g): return is_same(g, obs)):
				continue
			var touching: bool = group.any(func(g): return (g["pos"] as Vector2).distance_to(obs["pos"]) <= MODULE_TOUCH_DISTANCE)
			var dist: float = (first["pos"] as Vector2).distance_to(obs["pos"])
			if touching and dist < best_dist:
				best = obs
				best_dist = dist
		if best.is_empty():
			break
		group.append(best)
	for obs in group:
		_remove_module(obs)
	map.obstacles_changed()
	return group.size()

## Golpe de módulo: lo desliza en `dir` hasta `distance` o hasta chocar con un
## actor u otro obstáculo. Un tramo de tronco arrastra al tronco entero (ariete).
## Si choca un árbol con el jugador arriba, lo tira.
## Devuelve {"hit": "enemy" | "player" | "", "pos": Vector2, "tree": Dictionary}.
func slide_module(obs: Dictionary, dir: Vector2, distance: float) -> Dictionary:
	var group: Array = [obs]
	if obs.has("log_id"):
		group = map.terrain.obstacles().filter(func(o): return o.get("log_id", -1) == obs["log_id"])
	var step: Vector2 = dir.normalized() * distance
	var best_t := 1.0
	var hit := ""
	var hit_tree: Dictionary = {}
	for member in group:
		var from: Vector2 = member["pos"]
		var to: Vector2 = from + step
		var half := _module_half(member)
		best_t = minf(best_t, _bounds_t(from, to, half))
		for actor in [["enemy", map.enemy_pos, map.actors.enemy_radius()], ["player", map.player_pos, map.actors.player_radius()]]:
			var t := CombatMapQueries.first_contact_circle(from, to, actor[1], actor[2] + half)
			if t >= 0.0 and t < best_t:
				best_t = t
				hit = actor[0]
				hit_tree = {}
		for other in map.terrain.obstacles():
			if group.any(func(g): return is_same(g, other)) or CombatObstacle.type_of(other) == CombatObstacle.BRIDGE:
				continue
			var t: float
			if other.has("box"):
				t = CombatMapQueries.segment_hit_time_box(from, to, other["pos"], other["box"] * 0.5 + Vector2(half, half))
			else:
				t = CombatMapQueries.first_contact_circle(from, to, other["pos"], float(other["radius"]) + half)
			if t >= 0.0 and t < best_t:
				best_t = t
				hit = ""
				hit_tree = other if CombatObstacle.type_of(other) == CombatObstacle.TREE else {}
	var length := step.length()
	var travel := maxf(0.0, best_t * length - 0.02) if best_t < 1.0 else length
	var offset: Vector2 = step.normalized() * travel if length > 0.001 else Vector2.ZERO
	for member in group:
		var final: Vector2 = member["pos"] + offset
		member["pos"] = final
		var node = member.get("node")
		if is_instance_valid(node):
			var target := Vector3(final.x, node.position.y, final.y)
			if node.is_inside_tree():
				node.create_tween().tween_property(node, "position", target, 0.25)
			else:
				node.position = target
	map.obstacles_changed()
	if not hit_tree.is_empty():
		tree_system.knock_player_off(hit_tree, false)  # el golpe sacude el árbol
	return {"hit": hit, "pos": obs["pos"], "tree": hit_tree}

## Hasta qué fracción del segmento se puede mover algo de radio `half` sin salir del mapa.
func _bounds_t(from: Vector2, to: Vector2, half: float) -> float:
	return map.terrain.bounds_travel_fraction(from, to, half)

func _module_half(obs: Dictionary) -> float:
	if obs.has("box"):
		var b: Vector2 = obs["box"]
		return maxf(b.x, b.y) * 0.5
	return float(obs["radius"])
