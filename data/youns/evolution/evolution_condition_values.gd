class_name EvolutionConditionValues
extends EvolutionCondition

## Condición de STATS o CRIANZA: se cumple si pasan TODAS las comparaciones.
##   STATS   — key es una de YounStats.KEYS (lee save.youn_stats).
##   CRIANZA — key es un campo de PlayerSaveData (discipline, felicidad,
##             care_mistakes, weight, estres, confianza, aburrimiento, autocontrol...).

@export var checks: Array[EvolutionValueCheck] = []

func is_met(ctx: Dictionary) -> bool:
	var save: PlayerSaveData = ctx.get("save")
	if save == null or checks.is_empty():
		return false
	for check in checks:
		if check == null or not check.passes(_value_of(save, check.key)):
			return false
	return true

func _auto_description() -> String:
	var parts: PackedStringArray = []
	for check in checks:
		if check == null:
			continue
		var name := _key_name(check.key)
		var lo := _num(check.min_value)
		var hi := _num(check.max_value)
		if check.use_min and check.use_max:
			parts.append(LocalizationState.t("evolution.cond.between", [name, lo, hi]))
		elif check.use_max:
			parts.append(LocalizationState.t("evolution.cond.max", [name, hi]))
		else:
			parts.append(LocalizationState.t("evolution.cond.min", [name, lo]))
	var label := LocalizationState.t("evolution.cond.stats" if kind == Kind.STATS else "evolution.cond.care")
	return "%s: %s" % [label, LocalizationState.t("evolution.cond.and").join(parts)]

func _key_name(key: String) -> String:
	if kind == Kind.STATS:
		return _text("youn_stat." + key, key)
	return _text("status." + key, key)

static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else str(value)

func _value_of(save: PlayerSaveData, key: String) -> float:
	if kind == Kind.STATS:
		assert(key in YounStats.KEYS, "Estadística desconocida: %s" % key)
		return float(save.youn_stats.get(key, 0))
	assert(key in save, "Campo de crianza desconocido: %s" % key)
	return float(save.get(key))
