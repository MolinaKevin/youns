class_name EmotionEngine


static func evaluate(rules: Array[EmotionRule], ctx: Dictionary) -> Array[String]:
	if rules.is_empty():
		return []

	var sorted: Array[EmotionRule] = rules.duplicate()
	sorted.sort_custom(func(a: EmotionRule, b: EmotionRule) -> bool:
		return a.priority > b.priority)

	var active: Array[String] = []
	var blocked: Array[String] = []

	for active_name: String in ctx.get("active", [] as Array):
		for rule: EmotionRule in sorted:
			if rule.emotion_name == active_name:
				for b: String in rule.blocks:
					if b not in blocked:
						blocked.append(b)
				break

	for rule: EmotionRule in sorted:
		if rule.emotion_name.is_empty() or rule.emotion_name in blocked:
			continue
		var prob := rule.evaluate(ctx)
		var random: RandomSource = ctx.get("random")
		var legacy_rng: RandomNumberGenerator = ctx.get("rng")
		var roll := random.randf() if random else (legacy_rng.randf() if legacy_rng else randf())
		if prob > 0.0 and roll < prob:
			active.append(rule.emotion_name)
			for b: String in rule.blocks:
				if b not in blocked:
					blocked.append(b)

	return active
