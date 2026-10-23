class_name EvolutionConditionZone
extends EvolutionCondition

## BONUS: evolucionar estando en una zona (clave de ZoneManager.catalog).

@export var zone_id := ""

func _auto_description() -> String:
	return LocalizationState.t("evolution.cond.zone", [LocalizationState.location_name(zone_id)])

func is_met(ctx: Dictionary) -> bool:
	return not zone_id.is_empty() and ctx.get("zone", "") == zone_id
