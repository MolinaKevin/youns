class_name WorldNavigationService
extends RefCounted

## Fachada de la navegación exterior. WorldBoundary conserva la grilla y su
## geometría; este servicio evita que ZoneManager conozca esos detalles.

var _boundary: Node3D
var _is_inside: Callable


func configure(boundary: Node3D, is_inside: Callable) -> void:
	_boundary = boundary
	_is_inside = is_inside


func map_bounds() -> Rect2:
	return _boundary.get_map_bounds() if _boundary else Rect2()


func map_zone_edges() -> Array[Dictionary]:
	return _boundary.get_map_zone_edges() if _boundary else []


func map_zone_centers() -> Dictionary:
	return _boundary.get_map_zone_centers() if _boundary else {}


func find_path(from: Vector3, to: Vector3) -> Array[Vector2]:
	if _boundary == null or _is_inside.call():
		return []
	return _boundary.find_walkable_path(from, to)
