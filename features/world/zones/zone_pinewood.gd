extends ZoneBase

## Pinar (pinewood): al norte de la pradera oeste. Se sube por un pasillo desde
## el claro del Bosquecito; tiene dos claros y del lado de afuera (oeste y
## norte) termina en un precipicio de 30 m con un bosque bajo al fondo. Por
## el este sigue a las Lomas.
## Las paredes del borde las pone WorldBoundary; el pasto tiene su colisión
## (PinarMeadowFloor-colonly) y el precipicio su collider de cámara.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("Pinar")
