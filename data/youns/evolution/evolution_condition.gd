class_name EvolutionCondition
extends Resource

## Una condición para evolucionar A un Youn (va en YounData.evolution_conditions).
## Cada subclase revisa una cosa; kind dice de cuál de los 5 tipos del diseño es.
## ctx (lo arma EvolutionChecker):
##   save      PlayerSaveData
##   from      YounData que evoluciona
##   hour      hora del día (0–24)
##   zone      zona actual (ZoneManager.current_zone)

enum Kind { INTELIGENCIA, STATS, CRIANZA, CARTAS, BONUS }

@export var kind: Kind = Kind.BONUS
## Texto que se le revela al jugador cuando descubre la condición.
@export_multiline var description := ""

func is_met(_ctx: Dictionary) -> bool:
	return false

## Texto que ve el jugador al descubrirla: `description` si está escrita; si no,
## uno armado a partir de la condición.
func describe() -> String:
	return description if not description.strip_edges().is_empty() else _auto_description()

func _auto_description() -> String:
	return "?"

## Texto traducido, o `fallback` si no hay traducción para la clave.
static func _text(key: String, fallback: String) -> String:
	return LocalizationState.t(key) if LocalizationState.has_key(key) else fallback
