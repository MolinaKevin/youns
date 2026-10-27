class_name AutoDecoration
extends RefCounted

## Decoración procedural del mundo exterior (suelo de bosque y árboles) leída
## de meshes guía hechos en Blender. Sólo decora: la grilla de WorldBoundary
## (caminable, paredes invisibles, zonas) no se entera de estas guías.
##
## Las guías son meshes de los .glb cuyo nombre empieza con:
## - AutoForest_*   suelo de bosque y árboles sobre sus triángulos.
## - AutoGround_*   sólo suelo, sin árboles.
## - NoAutoFill_*   ni suelo ni árboles ahí.
## - NoAutoTrees_*  suelo sí, árboles no.
## - AutoWater_*    agua: la superficie es la malla misma, con el material de
##                  WATER_MATERIAL (shader estilo PS1). No deja suelo ni
##                  árboles a su altura.
##
## Los árboles son los moldes "Bosque" de la biblioteca de árboles
## (ForestBuilder.TREE_LIBRARY, hecha en blender/arboles.blend).
##
## Se usa la geometría 3D real de cada guía: el suelo es la malla misma (a su
## altura) y cada árbol se apoya en la altura de la guía en ese punto. Una
## exclusión (NoAutoFill/NoAutoTrees) sólo vale para lo que está a menos de
## Y_TOLERANCE de altura: un NoAutoFill sobre la playa de abajo no borra el
## bosque de arriba del precipicio, y al revés.
##
## Las guías pueden estar dentro del .glb de cualquier mapa (se leen con el
## offset de su zona) o en WORLD_GUIDES, para los huecos entre mapas. En el
## juego se sacan de las zonas al instanciarlas (remove_guides): no se ven ni
## tienen colisión.

const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")
const DebugLogging := preload("res://shared/debug_logging.gd")

enum Kind { FOREST, GROUND, NO_FILL, NO_TREES, WATER }
const PREFIXES := {
	"AutoForest_": Kind.FOREST,
	"AutoGround_": Kind.GROUND,
	"NoAutoFill_": Kind.NO_FILL,
	"NoAutoTrees_": Kind.NO_TREES,
	"AutoWater_": Kind.WATER,
}
## Distancia en Y hasta la que una exclusión afecta al suelo/árbol de otra guía.
const Y_TOLERANCE := 4.0
## Un árbol sólo va si la guía de bosque sigue al menos esto hacia los cuatro
## lados (a su misma altura): así no quedan árboles en el borde de una guía,
## colgando sobre un precipicio o fuera de lo que se dibujó.
const TREE_EDGE_MARGIN := 1.5
const TREE_EDGE_HEIGHT := 1.0
## Donde un NoAutoFill toca el suelo, sus triángulos se cortan hasta este largo
## de arista para que el recorte siga la forma de la exclusión.
const MAX_EDGE := 4.0
const WATER_MATERIAL := "res://features/world/water/water.tres"
## El agua se corta en triángulos de hasta este largo para que el shader pueda
## mover los vértices (las olas).
const WATER_MAX_EDGE := 3.0
## Grupo de la biblioteca de árboles que usa AutoForest_.
const TREE_GROUP := "Bosque"
## El suelo se repite cada tantos metros (igual que el plano de antes).
const GROUND_UV_SIZE := 16.0

var _tris := {
	Kind.FOREST: PackedVector3Array(),
	Kind.GROUND: PackedVector3Array(),
	Kind.NO_FILL: PackedVector3Array(),
	Kind.NO_TREES: PackedVector3Array(),
	Kind.WATER: PackedVector3Array(),
}
var _index := {}   # Kind -> _TriIndex (se arma en _ensure_index)
var _tree_positions: Array[Vector3] = []
var _ground_out := PackedVector3Array()   # lo va llenando _split_and_keep

## ¿Ese nombre de nodo es una guía de decoración?
static func is_guide(node_name: String) -> bool:
	return guide_kind(node_name) >= 0

static func guide_kind(node_name: String) -> int:
	for prefix in PREFIXES:
		if node_name.begins_with(prefix):
			return PREFIXES[prefix]
	return -1

## Saca de una zona recién instanciada las guías que trae su .glb (y lo que
## cuelgue de ellas, p. ej. una colisión): en el juego no se ven ni chocan.
static func remove_guides(root: Node) -> void:
	var found: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		if is_guide(String(node.name)):
			found.append(node)
	for node in found:
		if not is_instance_valid(node) or node.get_parent() == null:
			continue
		node.get_parent().remove_child(node)
		node.free()

## Lee las guías de una escena (.glb) puesta en `offset`.
func add_map(scene_path: String, offset: Vector3) -> void:
	var map: Node3D = (load(scene_path) as PackedScene).instantiate()
	add_node(map, offset)
	map.free()

## Lee las guías de un nodo ya instanciado (raíz de un .glb) puesto en `offset`.
func add_node(root: Node, offset: Vector3) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var kind := guide_kind(String(node.name))
		if kind < 0:
			continue
		var mi := node as MeshInstance3D
		var t := Transform3D(Basis(), offset) * _transform_in(mi, root)
		var faces := mi.mesh.get_faces()
		var out: PackedVector3Array = _tris[kind]
		for v in faces:
			out.append(t * v)
		_tris[kind] = out
	_index.clear()

## Triángulos de guía sueltos (en coordenadas del mundo), p. ej. para tests.
func add_triangles(kind: int, tris: PackedVector3Array) -> void:
	var out: PackedVector3Array = _tris[kind]
	out.append_array(tris)
	_tris[kind] = out
	_index.clear()

## Triángulos (3D, del mundo) de las guías AutoWater_ (para el agua futura).
func water_triangles() -> PackedVector3Array:
	return _tris[Kind.WATER]

func has_guides() -> bool:
	return not (_tris[Kind.FOREST] as PackedVector3Array).is_empty() or not (_tris[Kind.GROUND] as PackedVector3Array).is_empty()

## Agrega a `parent` el suelo y los árboles. `grid` es la grilla de
## WorldBoundary: sólo se consulta para no plantar árboles sobre lo caminable
## ni a menos de `clearance` celdas de su borde.
func build(parent: Node3D, grid: WorldBoundaryGrid, clearance: int, spacing: float, tree_seed: int, build_tree_meshes := true) -> void:
	var started_at := Time.get_ticks_msec()
	var checkpoint := started_at
	if DebugLogging.verbose_enabled():
		print("[AutoDecoration] Construyendo decoración global…")
	var ground := ground_triangles()
	checkpoint = _log_build_step("Preparación de suelo (%d triángulos)" % (ground.size() / 3), started_at, checkpoint)
	if not ground.is_empty():
		parent.add_child(_ground_mesh(ground))
	checkpoint = _log_build_step("Creación de malla de suelo", started_at, checkpoint)
	var water := water_triangles()
	checkpoint = _log_build_step("Preparación de agua (%d triángulos)" % (water.size() / 3), started_at, checkpoint)
	if not water.is_empty():
		parent.add_child(_water_mesh(water))
	checkpoint = _log_build_step("Creación de malla de agua", started_at, checkpoint)
	_tree_positions = tree_positions(grid, clearance, spacing, tree_seed)
	checkpoint = _log_build_step("Cálculo de %d posiciones de árboles" % _tree_positions.size(), started_at, checkpoint)
	if not build_tree_meshes or _tree_positions.is_empty():
		return
	var templates := ForestBuilder.library_templates(TREE_GROUP)
	checkpoint = _log_build_step("Carga de %d plantillas de árbol" % templates.size(), started_at, checkpoint)
	if templates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed + 1
	var trees: Array = []
	for p in _tree_positions:
		trees.append([rng.randi() % templates.size(), ForestBuilder.random_tree_transform(rng, p)])
	checkpoint = _log_build_step("Preparación de transformaciones", started_at, checkpoint)
	ForestBuilder.add_trees(parent, templates, trees)
	_log_build_step("Instanciación de árboles", started_at, checkpoint)


func _log_build_step(step: String, started_at: int, previous_at: int) -> int:
	var now := Time.get_ticks_msec()
	if DebugLogging.verbose_enabled():
		print("[AutoDecoration] %s: +%d ms (total: %d ms)" % [step, now - previous_at, now - started_at])
	return now

## Dónde quedaron los árboles del último build() (para tests y depuración).
func built_tree_positions() -> Array[Vector3]:
	return _tree_positions

# ── Suelo ───────────────────────────────────────────────────────────────────

## Triángulos (3D, del mundo) del suelo: los de AutoForest y AutoGround, sin
## lo que tapa un NoAutoFill a su altura.
func ground_triangles() -> PackedVector3Array:
	_ensure_index()
	var no_fill: _TriIndex = _index[Kind.NO_FILL]
	var water: _TriIndex = _index[Kind.WATER]
	_ground_out = PackedVector3Array()
	for kind in [Kind.FOREST, Kind.GROUND]:
		var tris: PackedVector3Array = _tris[kind]
		for i in range(0, tris.size(), 3):
			var a := tris[i]
			var b := tris[i + 1]
			var c := tris[i + 2]
			if _is_vertical(a, b, c):
				continue
			if no_fill.touches(_bbox(a, b, c)) or water.touches(_bbox(a, b, c)):
				_split_and_keep(a, b, c, no_fill, water)
			else:
				_ground_out.append(a)
				_ground_out.append(b)
				_ground_out.append(c)
	return _ground_out

func _split_and_keep(a: Vector3, b: Vector3, c: Vector3, no_fill: _TriIndex, water: _TriIndex) -> void:
	var ab := a.distance_to(b)
	var bc := b.distance_to(c)
	var ca := c.distance_to(a)
	var longest := maxf(ab, maxf(bc, ca))
	if longest > MAX_EDGE:
		# Partir por la arista más larga.
		if longest == ab:
			var m := (a + b) * 0.5
			_split_and_keep(a, m, c, no_fill, water)
			_split_and_keep(m, b, c, no_fill, water)
		elif longest == bc:
			var m := (b + c) * 0.5
			_split_and_keep(a, b, m, no_fill, water)
			_split_and_keep(a, m, c, no_fill, water)
		else:
			var m := (c + a) * 0.5
			_split_and_keep(a, b, m, no_fill, water)
			_split_and_keep(m, b, c, no_fill, water)
		return
	var center := (a + b + c) / 3.0
	var c2 := Vector2(center.x, center.z)
	if not no_fill.covers(c2, center.y, Y_TOLERANCE) and not water.covers(c2, center.y, Y_TOLERANCE):
		_ground_out.append(a)
		_ground_out.append(b)
		_ground_out.append(c)

func _ground_mesh(tris: PackedVector3Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tris.size(), 3):
		var a := tris[i]
		var b := tris[i + 1]
		var c := tris[i + 2]
		var n := (b - a).cross(c - a).normalized()
		if n.y < 0.0:
			n = -n
		for v in [a, b, c]:
			st.set_normal(n)
			st.set_uv(Vector2(v.x, v.z) / GROUND_UV_SIZE)
			st.add_vertex(v)
	var mat := ForestBuilder.ground_material().duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "AutoGround"
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi

# ── Agua ────────────────────────────────────────────────────────────────────

func _water_mesh(tris: PackedVector3Array) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, tris.size(), 3):
		if _is_vertical(tris[i], tris[i + 1], tris[i + 2]):
			continue
		_add_water_tri(st, tris[i], tris[i + 1], tris[i + 2])
	var mi := MeshInstance3D.new()
	mi.name = "AutoWater"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ResourceLoader.exists(WATER_MATERIAL):
		mi.material_override = load(WATER_MATERIAL)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.45, 0.7, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
	return mi

func _add_water_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var ab := a.distance_to(b)
	var bc := b.distance_to(c)
	var ca := c.distance_to(a)
	var longest := maxf(ab, maxf(bc, ca))
	if longest > WATER_MAX_EDGE:
		if longest == ab:
			var m := (a + b) * 0.5
			_add_water_tri(st, a, m, c)
			_add_water_tri(st, m, b, c)
		elif longest == bc:
			var m := (b + c) * 0.5
			_add_water_tri(st, a, b, m)
			_add_water_tri(st, a, m, c)
		else:
			var m := (c + a) * 0.5
			_add_water_tri(st, a, b, m)
			_add_water_tri(st, m, b, c)
		return
	for v in [a, b, c]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(v.x, v.z) / GROUND_UV_SIZE)
		st.add_vertex(v)

# ── Árboles ─────────────────────────────────────────────────────────────────

## Puntos (3D) donde va un árbol: una grilla con jitter sobre las guías
## AutoForest, a la altura de la guía, salvo donde hay un NoAutoFill o un
## NoAutoTrees a esa altura, sobre lo caminable o pegado a su borde.
func tree_positions(grid: WorldBoundaryGrid, clearance: int, spacing: float, tree_seed: int) -> Array[Vector3]:
	_ensure_index()
	var result: Array[Vector3] = []
	var forest: _TriIndex = _index[Kind.FOREST]
	if forest.is_empty():
		return result
	var no_fill: _TriIndex = _index[Kind.NO_FILL]
	var no_trees: _TriIndex = _index[Kind.NO_TREES]
	var water: _TriIndex = _index[Kind.WATER]
	var dist := PackedInt32Array()
	if grid != null and clearance > 0:
		dist = grid.distance_to_walkable(clearance)
	var area := forest.bounds
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var origin := (area.position / spacing).floor() * spacing
	var cols := int(ceil((area.end.x - origin.x) / spacing))
	var rows := int(ceil((area.end.y - origin.y) / spacing))
	for gz in rows:
		for gx in cols:
			var p := origin + (Vector2(gx, gz) + Vector2(0.5, 0.5) + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45))) * spacing
			# Es una consulta O(1) a la grilla y descarta enseguida el margen
			# caminable. Antes se hacían hasta cinco búsquedas geométricas caras
			# por punto para terminar descartándolo acá.
			if grid != null and _too_close_to_walkable(grid, dist, clearance, p):
				continue
			var heights := forest.heights_at(p)
			if heights.is_empty():
				continue
			for y in heights:
				if no_fill.covers(p, y, Y_TOLERANCE) or no_trees.covers(p, y, Y_TOLERANCE) or water.covers(p, y, Y_TOLERANCE):
					continue
				if not _well_inside(forest, p, y):
					continue
				result.append(Vector3(p.x, y, p.y))
	return result

func _well_inside(forest: _TriIndex, p: Vector2, y: float) -> bool:
	for d in [Vector2(TREE_EDGE_MARGIN, 0), Vector2(-TREE_EDGE_MARGIN, 0), Vector2(0, TREE_EDGE_MARGIN), Vector2(0, -TREE_EDGE_MARGIN)]:
		if not forest.covers(p + d, y, TREE_EDGE_HEIGHT):
			return false
	return true

func _too_close_to_walkable(grid: WorldBoundaryGrid, dist: PackedInt32Array, clearance: int, p: Vector2) -> bool:
	var c := ((p - grid.origin) / WorldBoundaryGrid.CELL).floor()
	var ix := int(c.x)
	var iz := int(c.y)
	if ix < 0 or iz < 0 or ix >= grid.w or iz >= grid.h:
		return false
	if grid.cell_at(ix, iz) == WorldBoundaryGrid.WALKABLE:
		return true
	return not dist.is_empty() and dist[grid.idx(ix, iz)] < clearance

# ── Ayudas ──────────────────────────────────────────────────────────────────

func _ensure_index() -> void:
	if not _index.is_empty():
		return
	for kind in _tris:
		_index[kind] = _TriIndex.new(_tris[kind])

static func _is_vertical(a: Vector3, b: Vector3, c: Vector3) -> bool:
	return absf((b - a).cross(c - a).y) < 1e-6

static func _bbox(a: Vector3, b: Vector3, c: Vector3) -> Rect2:
	var r := Rect2(Vector2(a.x, a.z), Vector2.ZERO)
	r = r.expand(Vector2(b.x, b.z))
	return r.expand(Vector2(c.x, c.z))

static func _transform_in(node: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	while node != root and node != null:
		t = (node as Node3D).transform * t
		node = node.get_parent()
	return t

## Triángulos 3D indexados por baldes en XZ: dado un punto, qué alturas tienen
## las guías que lo cubren.
class _TriIndex:
	const BUCKET := 16.0
	var tris: PackedVector3Array
	var buckets := {}   # Vector2i -> PackedInt32Array (índice del 1.er vértice)
	var bounds := Rect2()

	func _init(t: PackedVector3Array) -> void:
		tris = t
		var first := true
		for i in range(0, tris.size(), 3):
			var r := Rect2(Vector2(tris[i].x, tris[i].z), Vector2.ZERO)
			r = r.expand(Vector2(tris[i + 1].x, tris[i + 1].z)).expand(Vector2(tris[i + 2].x, tris[i + 2].z))
			if r.size.x <= 0.0 and r.size.y <= 0.0:
				continue
			bounds = r if first else bounds.merge(r)
			first = false
			var lo := (r.position / BUCKET).floor()
			var hi := (r.end / BUCKET).floor()
			for bz in range(int(lo.y), int(hi.y) + 1):
				for bx in range(int(lo.x), int(hi.x) + 1):
					var key := Vector2i(bx, bz)
					var list: PackedInt32Array = buckets.get(key, PackedInt32Array())
					list.append(i)
					buckets[key] = list

	func is_empty() -> bool:
		return buckets.is_empty()

	## ¿Algún triángulo cae (en XZ) cerca de este rectángulo?
	func touches(r: Rect2) -> bool:
		if buckets.is_empty():
			return false
		var lo := (r.position / BUCKET).floor()
		var hi := (r.end / BUCKET).floor()
		# Un balde compartido sólo es una aproximación. Sin esta segunda
		# comprobación, un NoAutoFill pequeño hacía subdividir todos los
		# triángulos de guía que cayeran dentro de los mismos 16 m, incluso a
		# varios metros de distancia. En el mundo grande eso multiplicaba por
		# cientos la malla y el tiempo de arranque.
		var seen := {}
		for bz in range(int(lo.y), int(hi.y) + 1):
			for bx in range(int(lo.x), int(hi.x) + 1):
				var key := Vector2i(bx, bz)
				if not buckets.has(key):
					continue
				for i in buckets[key]:
					if seen.has(i):
						continue
					seen[i] = true
					var tri := Rect2(Vector2(tris[i].x, tris[i].z), Vector2.ZERO)
					tri = tri.expand(Vector2(tris[i + 1].x, tris[i + 1].z))
					tri = tri.expand(Vector2(tris[i + 2].x, tris[i + 2].z))
					if tri.intersects(r) or tri.encloses(r) or r.encloses(tri):
						return true
		return false

	## Alturas de los triángulos que contienen a p (en XZ).
	func heights_at(p: Vector2) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		var key := Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET))
		if not buckets.has(key):
			return out
		for i in buckets[key]:
			var a := tris[i]
			var b := tris[i + 1]
			var c := tris[i + 2]
			var w := _bary(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z))
			if w.x < -1e-5 or w.y < -1e-5 or w.z < -1e-5:
				continue
			out.append(a.y * w.x + b.y * w.y + c.y * w.z)
		return out

	## ¿Hay un triángulo sobre p a menos de `tolerance` de la altura y?
	func covers(p: Vector2, y: float, tolerance: float) -> bool:
		for h in heights_at(p):
			if absf(h - y) <= tolerance:
				return true
		return false

	static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
		var v0 := b - a
		var v1 := c - a
		var v2 := p - a
		var d := v0.x * v1.y - v1.x * v0.y
		if absf(d) < 1e-9:
			return Vector3(-1, -1, -1)
		var v := (v2.x * v1.y - v1.x * v2.y) / d
		var w := (v0.x * v2.y - v2.x * v0.y) / d
		return Vector3(1.0 - v - w, v, w)
