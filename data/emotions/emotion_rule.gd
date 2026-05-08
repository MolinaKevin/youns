class_name EmotionRule
extends Resource

enum Comparison { GREATER = 0, LESS = 1, BOOL_TRUE = 2 }

@export var emotion_name: String = ""
@export var priority: int = 0
@export var stat_key: String = ""
@export var threshold: float = 70.0
@export var comparison: Comparison = Comparison.GREATER
@export var probability_curve: Curve
@export var blocks: PackedStringArray = []


func evaluate(ctx: Dictionary) -> float:
	var ps: PlayerSaveData = ctx.get("save")
	if ps == null or stat_key.is_empty():
		return 0.0
	var val := _get_stat_value(ps)
	if probability_curve:
		return probability_curve.sample(clampf(val / 100.0, 0.0, 1.0))
	match comparison:
		Comparison.GREATER:   return 1.0 if val >= threshold else 0.0
		Comparison.LESS:      return 1.0 if val <= threshold else 0.0
		Comparison.BOOL_TRUE: return 1.0 if val > 50.0 else 0.0
	return 0.0


func _get_stat_value(ps: PlayerSaveData) -> float:
	var raw = ps.get(stat_key)
	if raw == null:
		return 0.0
	if raw is bool:
		return 100.0 if raw else 0.0
	return float(raw)
