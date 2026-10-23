extends ZoneBase

## Lomas (hills): al norte del crossroads. Se sube por un pasillo desde su claro
## norte; dos claros, al oeste se une con el Pinar y al este con el Mirador.
## Al norte termina en el mismo precipicio que el Pinar.
## Las paredes del borde las pone WorldBoundary; el pasto tiene su colisión
## (LomasMeadowFloor-colonly) y el precipicio su collider de cámara.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Lomas")
