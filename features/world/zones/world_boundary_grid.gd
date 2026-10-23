class_name WorldBoundaryGrid
extends RefCounted

## Grilla 2D (XZ) que define el suelo caminable y a qué zona pertenece cada
## celda. WorldBoundary la llena con los rectángulos/triángulos de las zonas
## (fill_rect/fill_triangle/tag_rect/tag_triangle) y la consulta para levantar
## paredes y árboles (cell_at/needs_wall/distance_to_walkable); zone_at() y
## get_map_*() son la API que usan ZoneManager y el mapa técnico.

const CELL := 1.0

enum { EMPTY, WALKABLE, RESERVED, CLEAR }

var origin := Vector2.ZERO   # esquina (x, z) de la celda 0
var w := 0
var h := 0
var cells := PackedByteArray()
## A qué zona pertenece cada celda: índice en zone_names (0 = ninguna). Con
## esto ZoneManager sabe en qué zona está parado el jugador (zone_at).
var zone_of := PackedByteArray()
var zone_names: Array[String] = [""]

func setup(bounds: Rect2) -> void:
	origin = bounds.position.floor()
	w = int(ceil(bounds.size.x / CELL)) + 1
	h = int(ceil(bounds.size.y / CELL)) + 1
	cells.resize(w * h)
	cells.fill(EMPTY)
	zone_of.resize(w * h)
	zone_of.fill(0)

func idx(ix: int, iz: int) -> int:
	return ix + iz * w

func cell_center(ix: int, iz: int) -> Vector2:
	return origin + Vector2(ix + 0.5, iz + 0.5) * CELL

func cell_at(ix: int, iz: int) -> int:
	if ix < 0 or iz < 0 or ix >= w or iz >= h:
		return EMPTY
	return cells[idx(ix, iz)]

## Índices de las celdas cuyo centro cae en el rectángulo.
func rect_cells(r: Rect2) -> PackedInt32Array:
	var result := PackedInt32Array()
	var a := ((r.position - origin) / CELL).floor()
	var b := ((r.end - origin) / CELL).ceil()
	for iz in range(maxi(0, int(a.y)), mini(h, int(b.y))):
		for ix in range(maxi(0, int(a.x)), mini(w, int(b.x))):
			if r.has_point(cell_center(ix, iz)):
				result.append(idx(ix, iz))
	return result

## Índices de las celdas cuyo centro cae en el triángulo.
func triangle_cells(a: Vector2, b: Vector2, c: Vector2) -> PackedInt32Array:
	var result := PackedInt32Array()
	var lo := ((Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))) - origin) / CELL).floor()
	var hi := ((Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))) - origin) / CELL).ceil()
	for iz in range(maxi(0, int(lo.y)), mini(h, int(hi.y))):
		for ix in range(maxi(0, int(lo.x)), mini(w, int(hi.x))):
			if Geometry2D.point_is_inside_triangle(cell_center(ix, iz), a, b, c):
				result.append(idx(ix, iz))
	return result

# only_empty: no pisar lo que ya es caminable.
func fill_rect(r: Rect2, value: int, only_empty := false) -> void:
	for i in rect_cells(r):
		if not only_empty or cells[i] == EMPTY:
			cells[i] = value

# only_empty: igual que en fill_rect, no pisar lo que ya tiene algo.
func fill_triangle(a: Vector2, b: Vector2, c: Vector2, value := WALKABLE, only_empty := false) -> void:
	for i in triangle_cells(a, b, c):
		if not only_empty or cells[i] == EMPTY:
			cells[i] = value

## Tipo de la celda donde cae ese punto del mundo (EMPTY si está fuera).
func cell_type_at(pos: Vector3) -> int:
	var c := ((Vector2(pos.x, pos.z) - origin) / CELL).floor()
	return cell_at(int(c.x), int(c.y))

func zone_index(zone_id: String) -> int:
	var index := zone_names.find(zone_id)
	if index < 0:
		zone_names.append(zone_id)
		index = zone_names.size() - 1
	return index

func tag_rect(r: Rect2, zone_id: String) -> void:
	var z := zone_index(zone_id)
	for i in rect_cells(r):
		if zone_of[i] == 0:
			zone_of[i] = z

func tag_triangle(a: Vector2, b: Vector2, c: Vector2, zone_id: String) -> void:
	var z := zone_index(zone_id)
	for i in triangle_cells(a, b, c):
		if zone_of[i] == 0:
			zone_of[i] = z

func zone_at_cell(ix: int, iz: int) -> int:
	if ix < 0 or iz < 0 or ix >= w or iz >= h:
		return 0
	return zone_of[idx(ix, iz)]

## En qué zona está ese punto del mundo (clave de ZoneManager.catalog), según el
## suelo de cada zona. Vacío si no cae en ninguna (p. ej. en una pared).
func zone_at(pos: Vector3) -> String:
	if zone_of.is_empty():
		return ""
	var c := ((Vector2(pos.x, pos.z) - origin) / CELL).floor()
	var ix := int(c.x)
	var iz := int(c.y)
	if ix < 0 or iz < 0 or ix >= w or iz >= h:
		return ""
	return zone_names[zone_of[idx(ix, iz)]]


# ── Ruta de recuperación del compañero ──────────────────────────────────────

## Ruta A* por las celdas transitables reales del mundo. WALKABLE es el suelo
## de las zonas; RESERVED es el área del gym, que tiene su propio borde visual
## pero también se puede recorrer. CLEAR (río, cañón, roca) nunca forma parte
## de la ruta, por lo que el compañero no intenta cruzar un precipicio.
func find_walkable_path(from: Vector3, to: Vector3, max_visited := 8000) -> Array[Vector2]:
	var start := _nearest_walkable_cell(from)
	var goal := _nearest_walkable_cell(to)
	if start.x < 0 or goal.x < 0:
		return []
	if start == goal:
		return [cell_center(start.x, start.y)]

	var frontier: Array[Vector2i] = [start]
	var came_from := {start: start}
	var cost := {start: 0.0}
	var visited := 0
	while not frontier.is_empty() and visited < max_visited:
		var current_index := 0
		var current_score := INF
		for i in frontier.size():
			var candidate: Vector2i = frontier[i]
			var score: float = cost[candidate] + _heuristic(candidate, goal)
			if score < current_score:
				current_score = score
				current_index = i
		var current: Vector2i = frontier[current_index]
		frontier.remove_at(current_index)
		visited += 1
		if current == goal:
			return _reconstruct_path(came_from, current)
		for step in _path_neighbors():
			var next := current + step
			if not _is_path_walkable(next.x, next.y):
				continue
			# No cortar diagonalmente entre dos paredes o bordes de cañón.
			if step.x != 0 and step.y != 0 and (not _is_path_walkable(current.x + step.x, current.y) or not _is_path_walkable(current.x, current.y + step.y)):
				continue
			var step_cost := 1.41421356 if step.x != 0 and step.y != 0 else 1.0
			var new_cost: float = cost[current] + step_cost
			if not cost.has(next) or new_cost < cost[next]:
				cost[next] = new_cost
				came_from[next] = current
				if next not in frontier:
					frontier.append(next)
	return []


func _nearest_walkable_cell(pos: Vector3, max_radius := 8) -> Vector2i:
	var p := ((Vector2(pos.x, pos.z) - origin) / CELL).floor()
	var center := Vector2i(int(p.x), int(p.y))
	if _is_path_walkable(center.x, center.y):
		return center
	for radius in range(1, max_radius + 1):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dz) != radius:
					continue
				var candidate := center + Vector2i(dx, dz)
				if _is_path_walkable(candidate.x, candidate.y):
					return candidate
	return Vector2i(-1, -1)


func _is_path_walkable(ix: int, iz: int) -> bool:
	var cell := cell_at(ix, iz)
	return cell == WALKABLE or cell == RESERVED


static func _path_neighbors() -> Array[Vector2i]:
	return [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dz: int = abs(a.y - b.y)
	return float(maxi(dx, dz)) + (1.41421356 - 1.0) * float(mini(dx, dz))


func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2]:
	var path_cells: Array[Vector2i] = [current]
	while came_from[current] != current:
		current = came_from[current]
		path_cells.append(current)
	path_cells.reverse()
	var result: Array[Vector2] = []
	for cell in path_cells:
		result.append(cell_center(cell.x, cell.y))
	return result

## Datos geométricos para la cartografía técnica. Usan exactamente la misma
## grilla XZ que define el suelo caminable y la zona actual del jugador.
func get_map_bounds() -> Rect2:
	return Rect2(origin, Vector2(w, h) * CELL)

## Segmentos del borde de cada zona. Una arista aparece sólo si la celda vecina
## pertenece a otra zona (o a ninguna); así el mapa no depende de tamaños
## aproximados escritos a mano.
func get_map_zone_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for iz in h:
		for ix in w:
			var zone_index_at := zone_of[idx(ix, iz)]
			if zone_index_at == 0:
				continue
			var zone_id := zone_names[zone_index_at]
			var p := origin + Vector2(ix, iz) * CELL
			if zone_at_cell(ix, iz - 1) != zone_index_at:
				edges.append({"zone": zone_id, "from": p, "to": p + Vector2(CELL, 0)})
			if zone_at_cell(ix + 1, iz) != zone_index_at:
				edges.append({"zone": zone_id, "from": p + Vector2(CELL, 0), "to": p + Vector2(CELL, CELL)})
			if zone_at_cell(ix, iz + 1) != zone_index_at:
				edges.append({"zone": zone_id, "from": p + Vector2(CELL, CELL), "to": p + Vector2(0, CELL)})
			if zone_at_cell(ix - 1, iz) != zone_index_at:
				edges.append({"zone": zone_id, "from": p + Vector2(0, CELL), "to": p})
	return edges

## Centro visual de cada zona calculado desde sus celdas reales. Es preferible
## al origen de una escena para zonas irregulares, como la pradera.
func get_map_zone_centers() -> Dictionary:
	var sums: Dictionary = {}
	var counts: Dictionary = {}
	for iz in h:
		for ix in w:
			var zone_index_at := zone_of[idx(ix, iz)]
			if zone_index_at == 0:
				continue
			var zone_id := zone_names[zone_index_at]
			var cell_c := origin + (Vector2(ix, iz) + Vector2(0.5, 0.5)) * CELL
			sums[zone_id] = sums.get(zone_id, Vector2.ZERO) + cell_c
			counts[zone_id] = counts.get(zone_id, 0) + 1
	var centers: Dictionary = {}
	for zone_id in sums:
		centers[zone_id] = sums[zone_id] / float(counts[zone_id])
	return centers

# Entre una celda caminable y otra vacía (o de río) va pared; contra lo
# reservado (el bosque del gym) no, que ya tiene las suyas.
func needs_wall(a: int, b: int) -> bool:
	return (a == WALKABLE and (b == EMPTY or b == CLEAR)) or (b == WALKABLE and (a == EMPTY or a == CLEAR))

# Distancia (en celdas, 8 vecinos) de cada celda al suelo caminable más
# cercano, hasta max_dist + 1.
func distance_to_walkable(max_dist: int) -> PackedInt32Array:
	var far := max_dist + 1
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(far)
	# Arranca solo desde el contorno caminable: el interior no cambia nada.
	var frontier := PackedInt32Array()
	for i in cells.size():
		if cells[i] != WALKABLE:
			continue
		dist[i] = 0
		var ix := i % w
		var iz := floori(float(i) / float(w))
		if cell_at(ix - 1, iz) != WALKABLE or cell_at(ix + 1, iz) != WALKABLE or cell_at(ix, iz - 1) != WALKABLE or cell_at(ix, iz + 1) != WALKABLE:
			frontier.append(i)
	var d := 0
	while not frontier.is_empty() and d < far:
		d += 1
		var next := PackedInt32Array()
		for i in frontier:
			var ix := i % w
			var iz := floori(float(i) / float(w))
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = ix + dx
					var nz: int = iz + dz
					if nx < 0 or nz < 0 or nx >= w or nz >= h:
						continue
					var j := idx(nx, nz)
					if dist[j] > d:
						dist[j] = d
						next.append(j)
		frontier = next
	return dist
