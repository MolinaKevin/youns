class_name EmotionRuleTimeWindow
extends EmotionRule


func evaluate(ctx: Dictionary) -> float:
	var youn_data: YounData = ctx.get("youn_data")
	if youn_data == null:
		return 0.0
	var hour: float = GameState.time_of_day_hours
	var sh := float(youn_data.sleep_hour)
	var wh := float(youn_data.wake_hour)
	var in_range: bool
	if sh > wh:
		in_range = hour >= sh or hour < wh
	else:
		in_range = hour >= sh and hour < wh
	return 1.0 if in_range else 0.0
