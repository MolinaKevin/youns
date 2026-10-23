extends ZoneBase

## Mirador (overlook): al noreste del crossroads. Se sube desde su claro
## noreste (y desde las Lomas) a un claro grande que se asoma al precipicio
## por el norte y el este.
## Las paredes del borde las pone WorldBoundary; el pasto tiene su colisión
## (MiradorMeadowFloor-colonly) y el precipicio su collider de cámara.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Mirador")
