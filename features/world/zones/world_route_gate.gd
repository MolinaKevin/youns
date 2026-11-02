class_name WorldRouteGate
extends RefCounted

## Barrera + aviso + guía de una ruta bloqueada por ítem (ver zone_bend.gd/
## zone_right.gd): muestra la barrera y la guía mientras no está abierta,
## las apaga cuando se abre.

static func refresh(barrier: Node3D, warning: Area3D, guide: WorldRouteGuard, is_open: bool) -> void:
	var blocked := not is_open
	(barrier.get_node("Col") as CollisionShape3D).disabled = is_open
	barrier.visible = blocked
	warning.monitoring = blocked
	guide.visible = blocked
	guide.set_active(blocked)
