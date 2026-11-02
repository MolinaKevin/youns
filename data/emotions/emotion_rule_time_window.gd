class_name EmotionRuleTimeWindow
extends EmotionRule


func evaluate(ctx: Dictionary) -> float:
	var youn_data: YounData = ctx.get("youn_data")
	if youn_data == null:
		return 0.0
	var hour: float = GameState.time_of_day_hours
	var in_range := HourRange.contains(hour, youn_data.sleep_hour, youn_data.wake_hour)
	return 1.0 if in_range else 0.0
