class_name EmotionStateEntry
extends RefCounted

## Contrato serializable de una emoción activa. Se conserva como Dictionary en
## el guardado, pero las claves sensibles quedan centralizadas.

const HOUR := "hour"
const STAT_VALUE := "stat_value"
const CAUSE := "cause"
const TARGET_YOUN_PATH := "target_youn_path"

static func make(hour: float, stat_value: float = 100.0) -> Dictionary:
	return {HOUR: hour, STAT_VALUE: stat_value}

static func hour_of(entry: Dictionary) -> float:
	return float(entry.get(HOUR, 0.0))

static func stat_value_of(entry: Dictionary) -> float:
	return float(entry.get(STAT_VALUE, 100.0))

static func set_hour(entry: Dictionary, value: float) -> void:
	entry[HOUR] = value

static func cause_of(entry: Dictionary, fallback: String) -> String:
	return str(entry.get(CAUSE, fallback))

static func target_path_of(entry: Dictionary) -> String:
	return str(entry.get(TARGET_YOUN_PATH, ""))
