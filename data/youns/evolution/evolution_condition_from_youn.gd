class_name EvolutionConditionFromYoun
extends EvolutionCondition

## BONUS: evolucionar desde un Youn específico. La usan los niños: bebé → niño
## es fijo, así que se cumple siempre.

@export_file("*.tres") var youn_path := ""

func is_met(ctx: Dictionary) -> bool:
	var from: YounData = ctx.get("from")
	return from != null and not youn_path.is_empty() and from.resource_path == youn_path

func _auto_description() -> String:
	var name := youn_path.get_file().get_basename()
	if ResourceLoader.exists(youn_path):
		var youn := load(youn_path) as YounData
		if youn != null and not youn.youn_name.is_empty():
			name = youn.youn_name
	return LocalizationState.t("evolution.cond.from_youn", [name])
