class_name GroundRaycast
extends RefCounted

## Rayo hacia abajo buscando el piso (lo usan youn_follow_movement.gd para
## recuperar al Youn que se cae, y youn_life_events.gd para apoyar una caca
## en el suelo). Cada llamador decide rango/máscara/excluidos y cómo manejar
## que no haya pegado contra nada — esto solo arma el query y tira el rayo.
static func hit_below(space_state: PhysicsDirectSpaceState3D, world_position: Vector3,
		up: float, down: float, exclude: Array[RID], mask: int = 0xFFFFFFFF) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		world_position + Vector3.UP * up,
		world_position + Vector3.DOWN * down,
		mask)
	query.exclude = exclude
	return space_state.intersect_ray(query)
