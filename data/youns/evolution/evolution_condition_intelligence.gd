class_name EvolutionConditionIntelligence
extends EvolutionCondition

## INTELIGENCIA: la inteligencia del Youn que evoluciona está entre estas
## (ids como en docs/evoluciones: corporal, naturalista, logica...).

@export var intelligences: PackedStringArray = []

func _init() -> void:
	kind = Kind.INTELIGENCIA

func _auto_description() -> String:
	const Intelligences := preload("res://data/youns/intelligences.gd")
	var names: PackedStringArray = []
	for id in intelligences:
		names.append(Intelligences.display_name(id))
	return LocalizationState.t("evolution.cond.intelligence", [LocalizationState.t("evolution.cond.or").join(names)])

func is_met(ctx: Dictionary) -> bool:
	var from: YounData = ctx.get("from")
	if from == null:
		return false
	for id in from.intelligences:
		if id in intelligences:
			return true
	return false
