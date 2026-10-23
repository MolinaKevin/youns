extends ZoneBase

## Pradera oeste (left): se entra por el pasillo oeste del crossroads; el
## claro de la Ladera da contra el pie norte de la montaña del hub (por eso
## ZoneManager mantiene el hub cargado mientras se está acá).

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("PraderaOeste")
