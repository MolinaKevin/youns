class_name EvolutionConditionHour
extends EvolutionCondition

## BONUS: evolucionar dentro de una franja horaria [from_hour, to_hour).
## Si from_hour > to_hour cruza la medianoche (20 → 5 = de noche).

@export_range(0.0, 24.0, 0.5) var from_hour := 20.0
@export_range(0.0, 24.0, 0.5) var to_hour := 5.0

func _auto_description() -> String:
	return LocalizationState.t("evolution.cond.hour", [int(from_hour), int(to_hour)])

func is_met(ctx: Dictionary) -> bool:
	var hour := float(ctx.get("hour", -1.0))
	if hour < 0.0:
		return false
	if from_hour <= to_hour:
		return hour >= from_hour and hour < to_hour
	return hour >= from_hour or hour < to_hour
