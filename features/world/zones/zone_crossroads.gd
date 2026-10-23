extends ZoneBase

## Pradera norte (crossroads): une el sendero norte del hub con la pradera
## derecha (Hub2LeftMeadow) y deja un pasillo al oeste, hacia left.

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("PraderaNorte")
