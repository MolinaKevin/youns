extends Node3D

## Cierra el mundo exterior: calcula en una grilla qué parte del suelo es
## caminable (el suelo de cada zona) y pone paredes invisibles en todo su
## contorno y un bosque del lado de afuera. Lo crea ZoneManager y no depende de
## qué zonas estén cargadas.
##
## El gym tiene su propio bosque (GymForest): ese rectángulo queda reservado y
## acá no se ponen paredes ni árboles.

const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")
const GymForest := preload("res://features/world/zones/gym_forest.gd")

const CELL := 1.0
## Profundidad de la franja de bosque por fuera de las paredes.
const FOREST_DEPTH := 18
## Distancia mínima (en celdas) entre un árbol y el suelo caminable.
const TREE_CLEARANCE := 2
const TREE_SPACING := 3.2
const TREE_SEED := 4321
const WALL_HEIGHT := 6.0

## Tamaño del suelo de las zonas placeholder (crossroads, left).
const PLACEHOLDER_SIZE := 150.0
## Suelo del hub: el Ground del city_map mide 60×60 centrado en la zona.
const HUB_GROUND := Rect2(-30, -30, 60, 60)
## Sendero del borde norte del hub al crossroads, por el hueco entre los
## árboles del city_map (x 4 a 9). En coordenadas del mundo.
const NORTH_TRAIL := Rect2(4.6, -75.5, 3.8, 46.0)
## Suelo caminable de la pradera: sus meshes *Meadow.
const PRADERA_MAP := "res://assets/maps/hub/pradera_derecha.glb"
## El río del hub: acá van paredes pero no árboles (sería plantarlos en el agua).
const RIVER := Rect2(-38, -40, 8, 80)

enum { EMPTY, WALKABLE, RESERVED, CLEAR }

var _origin := Vector2.ZERO   # esquina (x, z) de la celda 0
var _w := 0
var _h := 0
var _cells := PackedByteArray()
## A qué zona pertenece cada celda: índice en _zone_names (0 = ninguna). Con
## esto ZoneManager sabe en qué zona está parado el jugador (zone_at).
var _zone_of := PackedByteArray()
var _zone_names: Array[String] = [""]

func build(zones: Dictionary) -> void:
	var walkable_rects: Array[Rect2] = []
	walkable_rects.append(_offset_rect(HUB_GROUND, zones["hub"]["offset"]))
	walkable_rects.append(NORTH_TRAIL)
	for id in ["crossroads", "left"]:
		var o: Vector3 = zones[id]["offset"]
		walkable_rects.append(Rect2(o.x - PLACEHOLDER_SIZE * 0.5, o.z - PLACEHOLDER_SIZE * 0.5, PLACEHOLDER_SIZE, PLACEHOLDER_SIZE))
	var meadow_tris := _meadow_triangles(zones["right"]["offset"])

	var gym_forest: Node = GymForest.new()
	var gym_rect: Rect2 = _offset_rect(gym_forest.covered_rect(), zones["gym"]["offset"])
	gym_forest.free()

	var bounds := gym_rect
	for r in walkable_rects:
		bounds = bounds.merge(r)
	for i in range(0, meadow_tris.size(), 3):
		for v in [meadow_tris[i], meadow_tris[i + 1], meadow_tris[i + 2]]:
			bounds = bounds.expand(v)
	bounds = bounds.grow(FOREST_DEPTH + 4)
	_origin = bounds.position.floor()
	_w = int(ceil(bounds.size.x / CELL)) + 1
	_h = int(ceil(bounds.size.y / CELL)) + 1
	_cells.resize(_w * _h)
	_cells.fill(EMPTY)

	for r in walkable_rects:
		_fill_rect(r, WALKABLE)
	for i in range(0, meadow_tris.size(), 3):
		_fill_triangle(meadow_tris[i], meadow_tris[i + 1], meadow_tris[i + 2])
	_fill_rect(gym_rect, RESERVED, true)
	_fill_rect(RIVER, CLEAR, true)

	# Mapa de zonas (la primera que marca una celda se la queda). El sendero
	# norte es del hub: desde ahí se mantiene cargado el crossroads.
	_zone_of.resize(_w * _h)
	_zone_of.fill(0)
	_tag_rect(walkable_rects[0], "hub")
	_tag_rect(NORTH_TRAIL, "hub")
	_tag_rect(walkable_rects[2], "crossroads")
	_tag_rect(walkable_rects[3], "left")
	for i in range(0, meadow_tris.size(), 3):
		_tag_triangle(meadow_tris[i], meadow_tris[i + 1], meadow_tris[i + 2], "right")
	_tag_rect(gym_rect, "gym")

	_build_walls()
	_build_trail()
	ForestBuilder.add_ground(self, Vector3(bounds.get_center().x, -0.08, bounds.get_center().y), bounds.size)
	_build_trees()

func _offset_rect(r: Rect2, offset: Vector3) -> Rect2:
	return Rect2(r.position + Vector2(offset.x, offset.z), r.size)

# Triángulos (XZ del mundo) de los meshes *Meadow de la pradera.
func _meadow_triangles(offset: Vector3) -> PackedVector2Array:
	var tris := PackedVector2Array()
	var map: Node3D = (load(PRADERA_MAP) as PackedScene).instantiate()
	for mi in map.find_children("*Meadow", "MeshInstance3D", true, false):
		var t := Transform3D(Basis(), offset) * _transform_in(mi, map)
		for v in (mi as MeshInstance3D).mesh.get_faces():
			var w: Vector3 = t * v
			tris.append(Vector2(w.x, w.z))
	map.free()
	return tris

func _transform_in(node: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	while node != root:
		t = (node as Node3D).transform * t
		node = node.get_parent()
	return t

# ── Grilla ──────────────────────────────────────────────────────────────────

func _idx(ix: int, iz: int) -> int:
	return ix + iz * _w

func _cell_center(ix: int, iz: int) -> Vector2:
	return _origin + Vector2(ix + 0.5, iz + 0.5) * CELL

func _cell_at(ix: int, iz: int) -> int:
	if ix < 0 or iz < 0 or ix >= _w or iz >= _h:
		return EMPTY
	return _cells[_idx(ix, iz)]

## Índices de las celdas cuyo centro cae en el rectángulo.
func _rect_cells(r: Rect2) -> PackedInt32Array:
	var result := PackedInt32Array()
	var a := ((r.position - _origin) / CELL).floor()
	var b := ((r.end - _origin) / CELL).ceil()
	for iz in range(maxi(0, int(a.y)), mini(_h, int(b.y))):
		for ix in range(maxi(0, int(a.x)), mini(_w, int(b.x))):
			if r.has_point(_cell_center(ix, iz)):
				result.append(_idx(ix, iz))
	return result

## Índices de las celdas cuyo centro cae en el triángulo.
func _triangle_cells(a: Vector2, b: Vector2, c: Vector2) -> PackedInt32Array:
	var result := PackedInt32Array()
	var lo := ((Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))) - _origin) / CELL).floor()
	var hi := ((Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))) - _origin) / CELL).ceil()
	for iz in range(maxi(0, int(lo.y)), mini(_h, int(hi.y))):
		for ix in range(maxi(0, int(lo.x)), mini(_w, int(hi.x))):
			if Geometry2D.point_is_inside_triangle(_cell_center(ix, iz), a, b, c):
				result.append(_idx(ix, iz))
	return result

# only_empty: no pisar lo que ya es caminable.
func _fill_rect(r: Rect2, value: int, only_empty := false) -> void:
	for i in _rect_cells(r):
		if not only_empty or _cells[i] == EMPTY:
			_cells[i] = value

func _fill_triangle(a: Vector2, b: Vector2, c: Vector2) -> void:
	for i in _triangle_cells(a, b, c):
		_cells[i] = WALKABLE

func _zone_index(zone_id: String) -> int:
	var index := _zone_names.find(zone_id)
	if index < 0:
		_zone_names.append(zone_id)
		index = _zone_names.size() - 1
	return index

func _tag_rect(r: Rect2, zone_id: String) -> void:
	var z := _zone_index(zone_id)
	for i in _rect_cells(r):
		if _zone_of[i] == 0:
			_zone_of[i] = z

func _tag_triangle(a: Vector2, b: Vector2, c: Vector2, zone_id: String) -> void:
	var z := _zone_index(zone_id)
	for i in _triangle_cells(a, b, c):
		if _zone_of[i] == 0:
			_zone_of[i] = z

## En qué zona está ese punto del mundo (clave de ZoneManager.ZONES), según el
## suelo de cada zona. Vacío si no cae en ninguna (p. ej. en una pared).
func zone_at(pos: Vector3) -> String:
	if _zone_of.is_empty():
		return ""
	var c := ((Vector2(pos.x, pos.z) - _origin) / CELL).floor()
	var ix := int(c.x)
	var iz := int(c.y)
	if ix < 0 or iz < 0 or ix >= _w or iz >= _h:
		return ""
	return _zone_names[_zone_of[_idx(ix, iz)]]


## Datos geométricos para la cartografía técnica. Usan exactamente la misma
## grilla XZ que define el suelo caminable y la zona actual del jugador.
func get_map_bounds() -> Rect2:
	return Rect2(_origin, Vector2(_w, _h) * CELL)


## Segmentos del borde de cada zona. Una arista aparece sólo si la celda vecina
## pertenece a otra zona (o a ninguna); así el mapa no depende de tamaños
## aproximados escritos a mano.
func get_map_zone_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for iz in _h:
		for ix in _w:
			var zone_index := _zone_of[_idx(ix, iz)]
			if zone_index == 0:
				continue
			var zone_id := _zone_names[zone_index]
			var p := _origin + Vector2(ix, iz) * CELL
			if _zone_at_cell(ix, iz - 1) != zone_index:
				edges.append({"zone": zone_id, "from": p, "to": p + Vector2(CELL, 0)})
			if _zone_at_cell(ix + 1, iz) != zone_index:
				edges.append({"zone": zone_id, "from": p + Vector2(CELL, 0), "to": p + Vector2(CELL, CELL)})
			if _zone_at_cell(ix, iz + 1) != zone_index:
				edges.append({"zone": zone_id, "from": p + Vector2(CELL, CELL), "to": p + Vector2(0, CELL)})
			if _zone_at_cell(ix - 1, iz) != zone_index:
				edges.append({"zone": zone_id, "from": p + Vector2(0, CELL), "to": p})
	return edges


## Centro visual de cada zona calculado desde sus celdas reales. Es preferible
## al origen de una escena para zonas irregulares, como la pradera.
func get_map_zone_centers() -> Dictionary:
	var sums: Dictionary = {}
	var counts: Dictionary = {}
	for iz in _h:
		for ix in _w:
			var zone_index := _zone_of[_idx(ix, iz)]
			if zone_index == 0:
				continue
			var zone_id := _zone_names[zone_index]
			var cell_center := _origin + (Vector2(ix, iz) + Vector2(0.5, 0.5)) * CELL
			sums[zone_id] = sums.get(zone_id, Vector2.ZERO) + cell_center
			counts[zone_id] = counts.get(zone_id, 0) + 1
	var centers: Dictionary = {}
	for zone_id in sums:
		centers[zone_id] = sums[zone_id] / float(counts[zone_id])
	return centers


func _zone_at_cell(ix: int, iz: int) -> int:
	if ix < 0 or iz < 0 or ix >= _w or iz >= _h:
		return 0
	return _zone_of[_idx(ix, iz)]

# Entre una celda caminable y otra vacía (o de río) va pared; contra lo
# reservado (el bosque del gym) no, que ya tiene las suyas.
func _needs_wall(a: int, b: int) -> bool:
	return (a == WALKABLE and (b == EMPTY or b == CLEAR)) or (b == WALKABLE and (a == EMPTY or a == CLEAR))

# ── Paredes ─────────────────────────────────────────────────────────────────

func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	# Bordes horizontales (entre la fila iz-1 y la iz), unidos en tramos.
	for iz in range(1, _h):
		var run_start := -1
		for ix in range(_w + 1):
			var edge := ix < _w and _needs_wall(_cell_at(ix, iz - 1), _cell_at(ix, iz))
			if edge and run_start < 0:
				run_start = ix
			elif not edge and run_start >= 0:
				var z := _origin.y + iz * CELL
				ForestBuilder.add_wall_between(body, Vector3(_origin.x + run_start * CELL, 0, z), Vector3(_origin.x + ix * CELL, 0, z), WALL_HEIGHT)
				run_start = -1
	# Bordes verticales (entre la columna ix-1 y la ix).
	for ix in range(1, _w):
		var run_start := -1
		for iz in range(_h + 1):
			var edge := iz < _h and _needs_wall(_cell_at(ix - 1, iz), _cell_at(ix, iz))
			if edge and run_start < 0:
				run_start = iz
			elif not edge and run_start >= 0:
				var x := _origin.x + ix * CELL
				ForestBuilder.add_wall_between(body, Vector3(x, 0, _origin.y + run_start * CELL), Vector3(x, 0, _origin.y + iz * CELL), WALL_HEIGHT)
				run_start = -1

# Suelo del sendero norte (tierra), con su propia colisión.
func _build_trail() -> void:
	var size := Vector3(NORTH_TRAIL.size.x, 0.1, NORTH_TRAIL.size.y)
	var center := Vector3(NORTH_TRAIL.get_center().x, -0.04, NORTH_TRAIL.get_center().y)
	var body := StaticBody3D.new()
	body.name = "NorthTrail"
	body.position = center
	add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.3)
	mat.roughness = 1.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

# ── Árboles ─────────────────────────────────────────────────────────────────

func _build_trees() -> void:
	var dist := _distance_to_walkable()
	var templates := ForestBuilder.tree_templates()
	if templates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var trees: Array = []
	var cols := int(_w * CELL / TREE_SPACING)
	var rows := int(_h * CELL / TREE_SPACING)
	for gz in rows:
		for gx in cols:
			var p := _origin + (Vector2(gx, gz) + Vector2(0.5, 0.5) + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))) * TREE_SPACING
			var c := ((p - _origin) / CELL).floor()
			var ix := int(c.x)
			var iz := int(c.y)
			if _cell_at(ix, iz) != EMPTY:
				continue
			var d := dist[_idx(ix, iz)]
			if d < TREE_CLEARANCE or d > FOREST_DEPTH:
				continue
			trees.append([rng.randi() % templates.size(), ForestBuilder.random_tree_transform(rng, Vector3(p.x, 0, p.y))])
	ForestBuilder.add_trees(self, templates, trees)

# Distancia (en celdas, 8 vecinos) de cada celda al suelo caminable más cercano,
# hasta FOREST_DEPTH + 1.
func _distance_to_walkable() -> PackedInt32Array:
	var far := FOREST_DEPTH + 1
	var dist := PackedInt32Array()
	dist.resize(_w * _h)
	dist.fill(far)
	# Arranca solo desde el contorno caminable: el interior no cambia nada.
	var frontier := PackedInt32Array()
	for i in _cells.size():
		if _cells[i] != WALKABLE:
			continue
		dist[i] = 0
		var ix := i % _w
		var iz := floori(float(i) / float(_w))
		if _cell_at(ix - 1, iz) != WALKABLE or _cell_at(ix + 1, iz) != WALKABLE or _cell_at(ix, iz - 1) != WALKABLE or _cell_at(ix, iz + 1) != WALKABLE:
			frontier.append(i)
	var d := 0
	while not frontier.is_empty() and d < far:
		d += 1
		var next := PackedInt32Array()
		for i in frontier:
			var ix := i % _w
			var iz := floori(float(i) / float(_w))
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = ix + dx
					var nz: int = iz + dz
					if nx < 0 or nz < 0 or nx >= _w or nz >= _h:
						continue
					var j := _idx(nx, nz)
					if dist[j] > d:
						dist[j] = d
						next.append(j)
		frontier = next
	return dist
