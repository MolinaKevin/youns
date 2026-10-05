extends RefCounted

## Las 8 inteligencias (Howard Gardner): ids y color de cada una. Los ids son
## los de docs/evoluciones. PLACEHOLDER: los colores son de ejemplo (los de la
## página de evoluciones, oscurecidos para que se lea el texto de la carta).

const IDS: Array[String] = [
	"linguistica", "logica", "espacial", "musical",
	"corporal", "interpersonal", "intrapersonal", "naturalista",
]

const COLORS := {
	"linguistica":   Color("#e8a33d"),
	"logica":        Color("#4f8fe8"),
	"espacial":      Color("#35b7a8"),
	"musical":       Color("#c56ae0"),
	"corporal":      Color("#e0584f"),
	"interpersonal": Color("#e07fb0"),
	"intrapersonal": Color("#8f87e8"),
	"naturalista":   Color("#5cb85c"),
}

## Color vivo de la inteligencia (chips, etiquetas).
static func color(id: String) -> Color:
	return COLORS.get(id, Color.GRAY)

## Color de fondo de una mitad de carta con esta inteligencia.
static func half_color(id: String) -> Color:
	return color(id).darkened(0.4)

static func display_name(id: String) -> String:
	return LocalizationState.t("intelligence." + id)
