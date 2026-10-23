extends ZoneBase

## Playa (beach): sale del final del brazo este del Recodo, al nivel del fondo
## del cañón (y -24). Es ancha y abierta: el río sale del cañón y termina en la
## arena. Por ahora no tiene bordes modelados (ni acantilados ni bosque): sólo
## una pared invisible alrededor de la arena (PlayaWall-colonly), abierta hacia
## la playa del Recodo. PlayaHoyoCanyon (debajo de la arena) hace que
## WorldBoundary no tape la playa con su suelo de arriba.
##
## El acantilado del oeste (PlayaAcantiladoCanyon) sube hasta la pradera, y
## delante del descanso de la bajada del Recodo sigue en una punta de roca con
## colisión (PlayaRemateRock-col): ahí termina la vuelta del zigzag.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Playa")
