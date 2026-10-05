class_name EvolutionConditionDominantStat
extends EvolutionCondition

## STATS: `stat` es la stat más alta del Youn que evoluciona (o empata arriba).
## La usan los rookies: niño → rookie va al rookie dueño de la stat dominante
## (YounData.dominant_stats), así que cada rookie tiene una por cada una de sus
## 4 stats.

@export var stat := ""

func _init() -> void:
	kind = Kind.STATS

func is_met(ctx: Dictionary) -> bool:
	var save: PlayerSaveData = ctx.get("save")
	if save == null or stat.is_empty():
		return false
	return stat in EvolutionChecker.dominant_stats(save.youn_stats)

func _auto_description() -> String:
	return LocalizationState.t("evolution.cond.dominant", [_text("youn_stat." + stat, stat)])
