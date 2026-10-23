extends ZoneBase

## Codo (elbow): pasto en forma de L detrás de la montaña. Se entra desde el
## Valle de la pradera oeste. Del lado de afuera (oeste y sur) hay un
## precipicio con un río en el fondo; en las puntas el cañón sube hasta el
## nivel del suelo. Las paredes del borde las pone WorldBoundary.
##
## Al este, detrás del gym, el pasto sigue en un claro al pie de la montaña
## (CodoCuevaMeadow) con la entrada de una cueva dibujada en la roca.
## WarpCueva (un Node3D vacío del .glb) marca dónde va el warp.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Codo")

## Dónde va el warp de la entrada de la cueva (coordenadas globales).
func cave_warp_position() -> Vector3:
	var marker := find_child("WarpCueva", true, false) as Node3D
	return marker.global_position if marker else global_position
