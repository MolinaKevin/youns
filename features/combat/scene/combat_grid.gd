class_name CombatGrid
extends RefCounted

## Grilla del combate: casillas cuadradas de CELL unidades de mundo.
## Movimiento en 8 direcciones: en cruz cuesta 1 casilla y en diagonal 1,41,
## así el alcance queda como un octógono, casi un círculo.
## Los personajes ocupan un círculo de casillas (su radio de huella), así que
## la validez de una casilla la decide quien llama, con un Callable.

## Mismo tamaño que las casillas que se dibujan en el mapa.
const CELL := 0.08

## Costos enteros (x100) para poder usar una cola por baldes, mucho más rápida
## que un heap en GDScript.
const ORTHO_COST := 100
const DIAG_COST := 141

const _ORTHO_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _DIAG_DIRS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

static func to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))

## Centro de la casilla en coordenadas de mundo.
static func to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL

## Cantidad de pasos de casilla que entra en una distancia de mundo.
static func steps_for(distance: float) -> int:
	return floori(distance / CELL + 0.001)

## Distancia en casillas entre dos casillas sin obstáculos (1 en cruz, 1,41 en diagonal).
static func octile(delta: Vector2i) -> float:
	var dx := absi(delta.x)
	var dy := absi(delta.y)
	return float(maxi(dx, dy) - mini(dx, dy)) + float(mini(dx, dy)) * DIAG_COST / ORTHO_COST

## Casillas alcanzables desde start con un costo de hasta max_steps casillas.
## passable: (cell: Vector2i) -> bool. La casilla de inicio siempre cuenta.
## En diagonal no se puede cortar esquinas: los dos vecinos en cruz tienen que
## ser transitables.
## Devuelve {cell: {"parent": Vector2i, "cost": float}} (cost en casillas).
static func reachable(start: Vector2i, max_steps: int, passable: Callable) -> Dictionary:
	# Dijkstra con cola por baldes sobre arreglos empaquetados del cuadrado que
	# cubre el alcance: mucho más rápido que diccionarios en GDScript.
	var max_cost := max_steps * ORTHO_COST
	var r := max_steps + 1
	var side := 2 * r + 1
	var origin := start - Vector2i(r, r)
	var n := side * side
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(max_cost + 1)
	var parent := PackedInt32Array()
	parent.resize(n)
	var state := PackedByteArray()  # 0 sin mirar, 1 transitable, 2 bloqueada
	state.resize(n)
	var s0 := r * side + r
	dist[s0] = 0
	parent[s0] = s0
	state[s0] = 1
	var buckets := {0: PackedInt32Array([s0])}
	var reached := PackedInt32Array([s0])
	var ortho := [1, -1, side, -side]
	var diag := [[1, side], [1, -side], [-1, side], [-1, -side]]
	for cost in range(max_cost + 1):
		if not buckets.has(cost):
			continue
		for idx in buckets[cost]:
			if dist[idx] != cost:
				continue  # entrada vieja: ya se llegó más barato
			var nc := cost + ORTHO_COST
			if nc <= max_cost:
				for off in ortho:
					var j: int = idx + off
					if nc < dist[j] and _open(j, side, origin, state, passable):
						if dist[j] > max_cost:
							reached.append(j)
						dist[j] = nc
						parent[j] = idx
						if not buckets.has(nc):
							buckets[nc] = PackedInt32Array()
						buckets[nc].append(j)
			var dc := cost + DIAG_COST
			if dc <= max_cost:
				for pair in diag:
					var j: int = idx + pair[0] + pair[1]
					if dc < dist[j] and _open(idx + pair[0], side, origin, state, passable) \
							and _open(idx + pair[1], side, origin, state, passable) \
							and _open(j, side, origin, state, passable):
						if dist[j] > max_cost:
							reached.append(j)
						dist[j] = dc
						parent[j] = idx
						if not buckets.has(dc):
							buckets[dc] = PackedInt32Array()
						buckets[dc].append(j)
		buckets.erase(cost)
	var result := {}
	for idx in reached:
		var cell := origin + Vector2i(idx % side, idx / side)
		var p := parent[idx]
		result[cell] = {"parent": origin + Vector2i(p % side, p / side), "cost": float(dist[idx]) / ORTHO_COST}
	return result

## Consulta (y guarda) si la casilla del índice idx es transitable.
static func _open(idx: int, side: int, origin: Vector2i, state: PackedByteArray, passable: Callable) -> bool:
	var st := state[idx]
	if st == 0:
		st = 1 if passable.call(origin + Vector2i(idx % side, idx / side)) else 2
		state[idx] = st
	return st == 1

## Camino de start a goal (ambos incluidos) usando el resultado de reachable().
## Vacío si goal no es alcanzable.
static func path_to(reach: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not reach.has(goal):
		return path
	var cell := goal
	while true:
		path.push_front(cell)
		var parent: Vector2i = reach[cell]["parent"]
		if parent == cell:
			break
		cell = parent
	return path

## Deja solo el inicio, las esquinas donde el camino dobla y el final.
static func corners(path: Array[Vector2i]) -> Array[Vector2i]:
	if path.size() <= 2:
		return path.duplicate()
	var result: Array[Vector2i] = [path[0]]
	for i in range(1, path.size() - 1):
		if path[i] - path[i - 1] != path[i + 1] - path[i]:
			result.append(path[i])
	result.append(path[-1])
	return result
