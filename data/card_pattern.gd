extends Resource
class_name CardPattern

## Geometría reutilizable de una línea de acción. El efecto (daño, estado,
## charco, etc.) sigue viviendo en CardActionLine.
@export_enum("none", "circle", "line", "cone") var shape: String = "none"
@export_enum("self", "selected_cell", "enemy") var origin: String = "self"
@export_enum("none", "cursor", "enemy") var direction: String = "none"

## Dimensiones expresadas en módulos. La línea dueña resuelve los extras y el
## multiplicador de stat; estos datos sólo describen cómo interpretar la forma.
@export var secondary_modules: int = 1
@export var start_offset_modules: int = 0
@export_range(5.0, 85.0, 1.0) var cone_half_angle: float = 35.0
@export_enum("stop", "pass") var collision: String = "stop"

func needs_direction() -> bool:
	return shape in ["line", "cone"] and direction != "none"
