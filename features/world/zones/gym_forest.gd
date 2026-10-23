extends Node3D

const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")

## Bosque que rodea al gym: paredes invisibles para no salir de la arena ni del
## camino al hub. El suelo y los árboles de alrededor ahora salen de la guía
## AutoForest_Gym (assets/maps/world/auto_fill.glb, ver AutoDecoration); con
## build_own_forest vuelve el bosque generado acá (árboles densos con
## MultiMesh y suelo de bosque). Coordenadas locales de la zona del gym: la arena está
## centrada en el origen y el camino al hub va hacia -Z hasta el borde del hub.

## Radio de la pared invisible alrededor de la arena (el anillo de árboles del
## gym.glb está entre 26 y 30).
@export var wall_radius := 31.5
## Medio ancho del pasillo del camino (el camino mide 6).
@export var path_half_width := 3.6
## z donde termina el camino y empieza el suelo del hub (borde sur del hub).
@export var hub_edge_z := -43.5
@export var wall_height := 6.0

## Medio lado del bosque: los árboles y el suelo llenan el cuadrado desde el
## borde del hub (hub_edge_z) hasta forest_radius, salvo la arena y el camino.
@export var forest_radius := 64.0
## Hacia el este (+X) el bosque se corta antes: más allá está la pradera.
@export var east_limit := 48.0
## Hacia el oeste (-X) el bosque termina antes del río que baja junto a la
## montaña del hub (x -16 del mundo). WorldBoundary usa el valor por defecto
## de acá.
@export var west_limit := -26.0
## Hacia el sur (+Z) el bosque termina antes: detrás está la ribera, con su
## propio bosque y el cañón del río (z 115 del mundo). WorldBoundary usa el
## valor por defecto de acá.
@export var south_limit := 42.0
@export var tree_spacing := 3.2
@export var tree_seed := 1234
## false: el suelo y los árboles los pone AutoDecoration desde AutoForest_Gym.
@export var build_own_forest := false

func _ready() -> void:
	_build_walls()
	if build_own_forest:
		_build_ground()
		_build_trees()

## Rectángulo (en XZ locales) que cubre este bosque. WorldBoundary no pone
## paredes ni árboles ahí.
func covered_rect() -> Rect2:
	return Rect2(_ground_min_x(), hub_edge_z, east_limit - _ground_min_x(), _ground_max_z() - hub_edge_z)

func _ground_min_x() -> float:
	return maxf(west_limit, -forest_radius - 8.0)

func _ground_max_z() -> float:
	return minf(forest_radius + 8.0, south_limit)

# ── Paredes ─────────────────────────────────────────────────────────────────

func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	# Anillo alrededor de la arena, con el hueco del camino (hacia -Z): los
	# segmentos que tocan el hueco se recortan justo en el borde del camino.
	var gap_x := path_half_width + 0.3
	var gap_z := -sqrt(wall_radius * wall_radius - gap_x * gap_x)
	var segments := 40
	for i in segments:
		var a := Vector3(sin(TAU * i / segments), 0, cos(TAU * i / segments)) * wall_radius
		var b := Vector3(sin(TAU * (i + 1) / segments), 0, cos(TAU * (i + 1) / segments)) * wall_radius
		var a_in := _in_path_gap(a, gap_x)
		var b_in := _in_path_gap(b, gap_x)
		if a_in and b_in:
			continue
		if a_in:
			a = Vector3(signf(b.x) * gap_x, 0, gap_z)
		elif b_in:
			b = Vector3(signf(a.x) * gap_x, 0, gap_z)
		ForestBuilder.add_wall_between(body, a, b, wall_height)
	# Lados del camino, desde el anillo hasta el hub.
	for side in [-1.0, 1.0]:
		ForestBuilder.add_wall_between(body, Vector3(side * gap_x, 0, gap_z), Vector3(side * gap_x, 0, hub_edge_z), wall_height)
	# Borde sur del hub a lo ancho de todo el bosque, salvo la boca del camino:
	# sin esto se podría entrar al bosque desde el hub o rodeándolo.
	ForestBuilder.add_wall_between(body, Vector3(_ground_min_x(), 0, hub_edge_z), Vector3(-gap_x, 0, hub_edge_z), wall_height)
	ForestBuilder.add_wall_between(body, Vector3(gap_x, 0, hub_edge_z), Vector3(east_limit, 0, hub_edge_z), wall_height)

func _in_path_gap(p: Vector3, gap_x: float) -> bool:
	return p.z < 0 and absf(p.x) < gap_x

# ── Suelo ───────────────────────────────────────────────────────────────────

func _build_ground() -> void:
	var rect := covered_rect()
	# Apenas por debajo del suelo del gym y del hub para que no parpadee.
	ForestBuilder.add_ground(self, Vector3(rect.get_center().x, -0.03, rect.get_center().y), rect.size)

# ── Árboles ─────────────────────────────────────────────────────────────────

func _build_trees() -> void:
	var templates := ForestBuilder.tree_templates(get_parent().get_node_or_null("GymMap"))
	if templates.is_empty():
		push_warning("GymForest: no se encontraron árboles molde en gym.glb")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	var trees: Array = []  # [índice de molde, Transform3D]
	var steps := int(ceil((forest_radius + 6.0) / tree_spacing))
	for gx in range(-steps, steps + 1):
		for gz in range(-steps, steps + 1):
			var p := Vector3(gx, 0, gz) * tree_spacing
			p += Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45)) * tree_spacing
			if not _is_forest(p):
				continue
			trees.append([rng.randi() % templates.size(), ForestBuilder.random_tree_transform(rng, p)])
	ForestBuilder.add_trees(self, templates, trees)

# ¿Va un árbol acá? Dentro del suelo, fuera de la arena y del camino, y del lado del gym respecto
# del borde del hub (del otro lado están el hub, el río y la pradera).
func _is_forest(p: Vector3) -> bool:
	if Vector2(p.x, p.z).length() < wall_radius + 0.8:
		return false
	if p.x < _ground_min_x() + 2.0 or p.x > east_limit - 1.5 or p.z > minf(forest_radius + 6.0, south_limit - 2.0):
		return false
	if p.z < hub_edge_z + 1.0:
		return false
	if absf(p.x) < path_half_width + 1.2 and p.z < 0:
		return false
	return true
