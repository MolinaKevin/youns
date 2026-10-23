class_name WorldCollisionLayers
extends RefCounted

## Capa 1: obstáculos, paredes y elementos interactuables.
## Capa 2: superficies sobre las que se puede apoyar un actor. El Youn usa
## exclusivamente esta capa cuando recupera distancia, para atravesar
## bloqueadores sin perder gravedad, pendientes ni suelo.
const OBSTACLES := 1
const GROUND := 2
## Capa 3: colisionadores simplificados de geometría visible que la cámara no
## puede atravesar. No incluye límites invisibles, barandas ni actores.
const CAMERA_TERRAIN := 4
const ACTOR_WORLD_MASK := OBSTACLES | GROUND


## Los mapas .glb exportan las colisiones con el nombre del mesh de Blender.
## Estos términos identifican superficies transitables; el resto conserva la
## capa de obstáculos. Se ejecuta al instanciar cada zona, antes de mostrarla.
static func configure_ground_colliders(root: Node) -> void:
	for node in root.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if _is_ground_body(body, root):
			body.collision_layer = GROUND
			# Las caras de los pisos exportados desde Blender no siempre miran
			# hacia arriba; con el reverso activo el jugador no las atraviesa.
			_enable_backfaces(body)


## Los colisionadores de cámara se modelan en Blender como mallas simples con
## "camcol" en el nombre, p.ej. Montana-camcol-colonly. Quedan sólo en esta
## capa: no cambian el movimiento del jugador ni las paredes invisibles.
static func configure_camera_terrain_colliders(root: Node) -> void:
	for node in root.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if _is_camera_terrain_body(body, root):
			body.collision_layer = CAMERA_TERRAIN
			_enable_backfaces(body)


## Los -colonly importados desde Blender suelen generar un
## ConcavePolygonShape3D. La cámara puede mirar la pared desde cualquiera de
## sus dos lados, así que el rayo debe detectar también el reverso de la malla.
static func _enable_backfaces(body: StaticBody3D) -> void:
	for node in body.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision.shape is ConcavePolygonShape3D:
			(collision.shape as ConcavePolygonShape3D).backface_collision = true


## Al importar un .glb, Godot suele crear un StaticBody3D llamado literalmente
## "StaticBody3D" debajo del mesh que tenía el sufijo -col en Blender. Por eso
## hay que mirar sus padres: RecodoBajadaRampa/StaticBody3D es suelo, mientras
## RecodoBajadaRail/StaticBody3D sigue siendo un obstáculo.
static func _is_ground_body(body: StaticBody3D, root: Node) -> bool:
	var node: Node = body
	while node != null and node != root:
		if _is_ground_name(String(node.name)):
			return true
		node = node.get_parent()
	return _is_ground_name(String(root.name))


static func _is_camera_terrain_body(body: StaticBody3D, root: Node) -> bool:
	var node: Node = body
	while node != null and node != root:
		if "camcol" in String(node.name).to_lower():
			return true
		node = node.get_parent()
	return "camcol" in String(root.name).to_lower()


static func _is_ground_name(node_name: String) -> bool:
	var lower := node_name.to_lower()
	return lower == "floor" \
		or "floor" in lower \
		or "ground" in lower \
		or "meadow" in lower \
		or "path" in lower \
		or "ramp" in lower \
		or "rellano" in lower \
		or "descanso" in lower \
		or "bridge" in lower
