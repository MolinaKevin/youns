extends Node3D

## Cierra el mundo exterior: calcula en una grilla (WorldBoundaryGrid) qué
## parte del suelo es caminable (el suelo de cada zona) y pone paredes
## invisibles en todo su contorno y un bosque del lado de afuera. Lo crea
## ZoneManager y no depende de qué zonas estén cargadas.
##
## El gym tiene su propio bosque (GymForest): ese rectángulo queda reservado y
## acá no se ponen paredes ni árboles.

const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")
const GymForest := preload("res://features/world/zones/gym_forest.gd")

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

var _grid := WorldBoundaryGrid.new()

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
	_grid.setup(bounds)

	for r in walkable_rects:
		_grid.fill_rect(r, WorldBoundaryGrid.WALKABLE)
	for i in range(0, meadow_tris.size(), 3):
		_grid.fill_triangle(meadow_tris[i], meadow_tris[i + 1], meadow_tris[i + 2])
	_grid.fill_rect(gym_rect, WorldBoundaryGrid.RESERVED, true)
	_grid.fill_rect(RIVER, WorldBoundaryGrid.CLEAR, true)

	# Mapa de zonas (la primera que marca una celda se la queda). El sendero
	# norte es del hub: desde ahí se mantiene cargado el crossroads.
	_grid.tag_rect(walkable_rects[0], "hub")
	_grid.tag_rect(NORTH_TRAIL, "hub")
	_grid.tag_rect(walkable_rects[2], "crossroads")
	_grid.tag_rect(walkable_rects[3], "left")
	for i in range(0, meadow_tris.size(), 3):
		_grid.tag_triangle(meadow_tris[i], meadow_tris[i + 1], meadow_tris[i + 2], "right")
	_grid.tag_rect(gym_rect, "gym")

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

# ── Zonas (fachada de WorldBoundaryGrid) ─────────────────────────────────────

## En qué zona está ese punto del mundo (clave de ZoneManager.ZONES).
func zone_at(pos: Vector3) -> String:
	return _grid.zone_at(pos)

func get_map_bounds() -> Rect2:
	return _grid.get_map_bounds()

func get_map_zone_edges() -> Array[Dictionary]:
	return _grid.get_map_zone_edges()

func get_map_zone_centers() -> Dictionary:
	return _grid.get_map_zone_centers()

# ── Paredes ─────────────────────────────────────────────────────────────────

func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	# Bordes horizontales (entre la fila iz-1 y la iz), unidos en tramos.
	for iz in range(1, _grid.h):
		var run_start := -1
		for ix in range(_grid.w + 1):
			var edge := ix < _grid.w and _grid.needs_wall(_grid.cell_at(ix, iz - 1), _grid.cell_at(ix, iz))
			if edge and run_start < 0:
				run_start = ix
			elif not edge and run_start >= 0:
				var z := _grid.origin.y + iz * WorldBoundaryGrid.CELL
				ForestBuilder.add_wall_between(body, Vector3(_grid.origin.x + run_start * WorldBoundaryGrid.CELL, 0, z), Vector3(_grid.origin.x + ix * WorldBoundaryGrid.CELL, 0, z), WALL_HEIGHT)
				run_start = -1
	# Bordes verticales (entre la columna ix-1 y la ix).
	for ix in range(1, _grid.w):
		var run_start := -1
		for iz in range(_grid.h + 1):
			var edge := iz < _grid.h and _grid.needs_wall(_grid.cell_at(ix - 1, iz), _grid.cell_at(ix, iz))
			if edge and run_start < 0:
				run_start = iz
			elif not edge and run_start >= 0:
				var x := _grid.origin.x + ix * WorldBoundaryGrid.CELL
				ForestBuilder.add_wall_between(body, Vector3(x, 0, _grid.origin.y + run_start * WorldBoundaryGrid.CELL), Vector3(x, 0, _grid.origin.y + iz * WorldBoundaryGrid.CELL), WALL_HEIGHT)
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
	var dist := _grid.distance_to_walkable(FOREST_DEPTH)
	var templates := ForestBuilder.tree_templates()
	if templates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = TREE_SEED
	var trees: Array = []
	var cols := int(_grid.w * WorldBoundaryGrid.CELL / TREE_SPACING)
	var rows := int(_grid.h * WorldBoundaryGrid.CELL / TREE_SPACING)
	for gz in rows:
		for gx in cols:
			var p := _grid.origin + (Vector2(gx, gz) + Vector2(0.5, 0.5) + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))) * TREE_SPACING
			var c := ((p - _grid.origin) / WorldBoundaryGrid.CELL).floor()
			var ix := int(c.x)
			var iz := int(c.y)
			if _grid.cell_at(ix, iz) != WorldBoundaryGrid.EMPTY:
				continue
			var d := dist[_grid.idx(ix, iz)]
			if d < TREE_CLEARANCE or d > FOREST_DEPTH:
				continue
			trees.append([rng.randi() % templates.size(), ForestBuilder.random_tree_transform(rng, Vector3(p.x, 0, p.y))])
	ForestBuilder.add_trees(self, templates, trees)
