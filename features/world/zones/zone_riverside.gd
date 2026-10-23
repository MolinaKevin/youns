extends ZoneBase

## Ribera (riverside): detrás del gym, del lado sur. El cañón con el río del
## codo sigue hacia el este hasta el recodo. En el medio, la pared norte del
## cañón se abre en una caleta: un claro de pasto abajo, al nivel del río
## (y -24), con su propio piso (RiberaCalaFloor-colonly) y su propia pared
## invisible alrededor del pasto (RiberaCalaWall-colonly): las paredes de
## WorldBoundary están a la altura del suelo de arriba y acá no frenan. Arriba
## es todo bosque, así que por ahora no se llega caminando.
##
## WarpAbertura (un Node3D vacío del .glb) marca el pie de la pared de roca
## donde va la abertura: ahí se pone el warp para entrar y salir de la caleta.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Ribera")

## Dónde va el warp de la abertura (coordenadas globales).
func warp_position() -> Vector3:
	var marker := find_child("WarpAbertura", true, false) as Node3D
	return marker.global_position if marker else global_position
