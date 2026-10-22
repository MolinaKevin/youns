extends RefCounted

## Las 8 inteligencias (Howard Gardner): ids y color de cada una. Los ids son
## los de docs/evoluciones. El color de cada una vive en su .tres propio
## (data/youns/intelligences/<id>.tres, IntelligenceData) — PLACEHOLDER: los
## colores son de ejemplo (los de la página de evoluciones, oscurecidos para
## que se lea el texto de la carta).

const IDS: Array[String] = [
	"linguistica", "logica", "espacial", "musical",
	"corporal", "interpersonal", "intrapersonal", "naturalista",
]

const DIR := "res://data/youns/intelligences/"

static var _colors: Dictionary = {}

static func _ensure_loaded() -> void:
	if not _colors.is_empty():
		return
	for id in IDS:
		var data := load(DIR + id + ".tres") as IntelligenceData
		_colors[id] = data.color if data else Color.GRAY

## Color vivo de la inteligencia (chips, etiquetas).
static func color(id: String) -> Color:
	_ensure_loaded()
	return _colors.get(id, Color.GRAY)

## Color de fondo de una mitad de carta con esta inteligencia.
static func half_color(id: String) -> Color:
	return color(id).darkened(0.4)

static func display_name(id: String) -> String:
	return LocalizationState.t("intelligence." + id)
