extends ZoneBase

## Meseta (cliffs): sus bordes son un precipicio sobre un cañón con un río
## en el fondo. La única entrada es el puente natural del este, al final del
## sendero que sale del Valle de la pradera oeste. Las paredes invisibles del
## borde las pone WorldBoundary (el cañón no es caminable).

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Meseta")
