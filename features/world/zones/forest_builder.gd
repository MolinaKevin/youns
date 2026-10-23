extends RefCounted

## Piezas comunes de los bosques que cierran el mundo (GymForest, WorldBoundary):
## árboles con MultiMesh usando los modelos del gym.glb, suelo de bosque y
## paredes invisibles.

const TREE_SOURCE := "res://assets/maps/gym/gym.glb"
## Biblioteca de árboles hecha en Blender (blender/arboles.blend). Cada molde es
## un nodo raíz Arbol_<Grupo>_<Nombre> (p. ej. Arbol_Bosque_Pino) con sus
## mallas adentro (tronco, copas). La base del tronco es el origen de la raíz.
const TREE_LIBRARY := "res://assets/maps/world/arboles.glb"
## Árboles del gym.glb que se usan de molde (tronco + dos copas).
const TREE_TEMPLATES := [0, 1, 5, 12]

## Moldes de árbol: cada uno es una lista de {mesh, offset} relativos a la base
## del tronco. `map` es una instancia del gym.glb (si es null, se carga una).
static func tree_templates(map: Node = null) -> Array:
	var own := map == null
	if own:
		map = (load(TREE_SOURCE) as PackedScene).instantiate()
	var templates := []
	for i in TREE_TEMPLATES:
		var trunk := map.find_child("gym_tree_trunk_%d" % i, true, false) as MeshInstance3D
		if trunk == null:
			continue
		var parts := []
		for mi in [trunk, map.find_child("gym_tree_crown_%d" % i, true, false), map.find_child("gym_tree_crown2_%d" % i, true, false)]:
			if mi is MeshInstance3D:
				parts.append({"mesh": mi.mesh, "offset": Transform3D(mi.basis, mi.position - trunk.position)})
		templates.append(parts)
	if own:
		map.free()
	return templates

## Moldes de la biblioteca de árboles para un grupo ("Bosque", "Playa"...):
## una lista de {mesh, offset} por molde, como tree_templates(). Si no está la
## biblioteca o el grupo, usa los árboles del gym.glb.
static func library_templates(group := "Bosque") -> Array:
	if not ResourceLoader.exists(TREE_LIBRARY):
		return tree_templates()
	var lib: Node = (load(TREE_LIBRARY) as PackedScene).instantiate()
	var templates := []
	var prefix := "Arbol_%s_" % group
	for root in lib.find_children(prefix + "*", "Node3D", true, false):
		if root is MeshInstance3D:
			continue   # es una pieza (tronco, copa), no la raíz del molde
		var parts := []
		for mi in (root as Node3D).find_children("*", "MeshInstance3D", true, false):
			var t := Transform3D()
			var node: Node = mi
			while node != root:
				t = (node as Node3D).transform * t
				node = node.get_parent()
			parts.append({"mesh": (mi as MeshInstance3D).mesh, "offset": t})
		if not parts.is_empty():
			templates.append(parts)
	lib.free()
	if templates.is_empty():
		return tree_templates()
	return templates

## Transform de un árbol en `pos` con giro y tamaño al azar.
static func random_tree_transform(rng: RandomNumberGenerator, pos: Vector3) -> Transform3D:
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.8))
	return Transform3D(basis, pos)

## Agrega a `parent` los MultiMesh de los árboles. `trees` es una lista de
## [índice de molde, Transform3D].
static func add_trees(parent: Node3D, templates: Array, trees: Array) -> void:
	for t in templates.size():
		var mine := trees.filter(func(tree: Array) -> bool: return tree[0] == t)
		if mine.is_empty():
			continue
		for part in templates[t]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part["mesh"]
			mm.instance_count = mine.size()
			for k in mine.size():
				mm.set_instance_transform(k, mine[k][1] * part["offset"])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			parent.add_child(mmi)

## Plano de suelo de bosque (ruido en verdes y marrones) centrado en `center`.
static func add_ground(parent: Node3D, center: Vector3, size: Vector2) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var mat := _ground_material().duplicate() as StandardMaterial3D
	mat.uv1_scale = Vector3(size.x / 16.0, size.y / 16.0, 1)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "ForestGround"
	mi.mesh = plane
	mi.position = center
	parent.add_child(mi)
	return mi

static var _ground_mat: StandardMaterial3D = null

static func _ground_material() -> StandardMaterial3D:
	if _ground_mat:
		return _ground_mat
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.17, 0.24, 0.11))
	ramp.set_color(1, Color(0.30, 0.38, 0.17))
	ramp.add_point(0.45, Color(0.22, 0.30, 0.13))
	ramp.add_point(0.7, Color(0.30, 0.25, 0.15))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_texture = tex
	_ground_mat.roughness = 1.0
	return _ground_mat

## Pared invisible de a a b (en el suelo), un poco más larga para que las
## juntas no dejen huecos.
static func add_wall_between(body: StaticBody3D, a: Vector3, b: Vector3, height: float) -> void:
	var d := b - a
	add_wall(body, (a + b) * 0.5, Vector3(0.6, height, d.length() + 0.6), atan2(d.x, d.z))

static func add_wall(body: StaticBody3D, center: Vector3, size: Vector3, angle: float) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = center + Vector3(0, size.y * 0.5, 0)
	col.rotation.y = angle
	body.add_child(col)
