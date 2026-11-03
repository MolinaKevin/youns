class_name YounOrientation
extends RefCounted

## Orientación de un modelo suelto de Youn hacia un objetivo del mundo.
##
## Los cuerpos que cuelgan de Youn3D reciben mesh_rotation_y como corrección
## local. Un modelo suelto (por ejemplo, en una cinemática) se orienta primero
## con look_at(), cuyo frente es -Z, por lo que además necesita media vuelta
## para coincidir con la convención de movimiento del juego. mesh_rotation_y
## queda como el único ajuste específico de cada FBX.
static func face_target(model: Node3D, target: Vector3, data: YounData) -> void:
	if model == null or data == null:
		return
	var flat_target := Vector3(target.x, model.global_position.y, target.z)
	if model.global_position.distance_squared_to(flat_target) < 0.0001:
		return
	model.look_at(flat_target, Vector3.UP)
	model.rotation.y += PI + data.mesh_rotation_y

## Gira `node` hacia `target` en el plano XZ, sin tocarlo si ya está pegado
## (a diferencia de CutsceneScene3D.yaw_toward(), que devolvería 0 y lo haría
## mirar al frente del mundo en vez de dejarlo como está). Lo comparten
## youn_interaction.gd y bathroom_sequence.gd.
static func face_toward(node: Node3D, target: Vector3) -> void:
	var d := target - node.global_position
	d.y = 0.0
	if d.length() > 0.05:
		node.rotation.y = atan2(d.x, d.z)
