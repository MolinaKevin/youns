class_name EmotionEngine


static func evaluate(rules: Array[EmotionRule], ctx: Dictionary) -> Array[String]:
	if rules.is_empty():
		return []

	var sorted: Array[EmotionRule] = rules.duplicate()
	sorted.sort_custom(func(a: EmotionRule, b: EmotionRule) -> bool:
		return a.priority > b.priority)

	var active: Array[String] = []
	var blocked: Array[String] = []

	for rule: EmotionRule in sorted:
		if rule.emotion_name.is_empty() or rule.emotion_name in blocked:
			continue
		var prob := rule.evaluate(ctx)
		if prob > 0.0 and randf() < prob:
			active.append(rule.emotion_name)
			for b: String in rule.blocks:
				if b not in blocked:
					blocked.append(b)

	return active
