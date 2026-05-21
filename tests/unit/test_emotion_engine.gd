extends GutTest

var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()


func _make_rule(emotion: String, stat: String, threshold: float, comparison: EmotionRule.Comparison, priority: int = 0) -> EmotionRule:
	var rule := EmotionRule.new()
	rule.emotion_name = emotion
	rule.stat_key = stat
	rule.threshold = threshold
	rule.comparison = comparison
	rule.priority = priority
	return rule


# ── básico ────────────────────────────────────────────────────────────────────

func test_evaluate_empty_rules_returns_empty() -> void:
	var result := EmotionEngine.evaluate([], {"save": save})
	assert_eq(result, [])


func test_evaluate_triggers_matching_rule() -> void:
	save.felicidad = 90
	var rule := _make_rule("happy", "felicidad", 70.0, EmotionRule.Comparison.GREATER)
	var result := EmotionEngine.evaluate([rule], {"save": save})
	assert_has(result, "happy")


func test_evaluate_does_not_trigger_non_matching_rule() -> void:
	save.felicidad = 30
	var rule := _make_rule("happy", "felicidad", 70.0, EmotionRule.Comparison.GREATER)
	var result := EmotionEngine.evaluate([rule], {"save": save})
	assert_does_not_have(result, "happy")


# ── blocks ────────────────────────────────────────────────────────────────────

func test_higher_priority_rule_blocks_lower() -> void:
	save.felicidad = 90
	save.estres = 20

	var happy := _make_rule("happy", "felicidad", 70.0, EmotionRule.Comparison.GREATER, 10)
	happy.blocks = PackedStringArray(["stressed"])

	var stressed := _make_rule("stressed", "estres", 30.0, EmotionRule.Comparison.LESS, 5)

	var result := EmotionEngine.evaluate([stressed, happy], {"save": save})
	assert_has(result, "happy")
	assert_does_not_have(result, "stressed")


func test_lower_priority_rule_does_not_block_higher() -> void:
	save.felicidad = 90
	save.estres = 20

	var happy := _make_rule("happy", "felicidad", 70.0, EmotionRule.Comparison.GREATER, 5)
	var stressed := _make_rule("stressed", "estres", 30.0, EmotionRule.Comparison.LESS, 10)
	stressed.blocks = PackedStringArray(["happy"])

	var result := EmotionEngine.evaluate([stressed, happy], {"save": save})
	assert_does_not_have(result, "happy")
	assert_has(result, "stressed")


# ── múltiples reglas sin conflicto ────────────────────────────────────────────

func test_multiple_independent_rules_all_trigger() -> void:
	save.felicidad = 90
	save.estres = 5

	var happy := _make_rule("happy", "felicidad", 70.0, EmotionRule.Comparison.GREATER)
	var calm := _make_rule("calm", "estres", 20.0, EmotionRule.Comparison.LESS)

	var result := EmotionEngine.evaluate([happy, calm], {"save": save})
	assert_has(result, "happy")
	assert_has(result, "calm")


# ── emotion_name vacío se ignora ──────────────────────────────────────────────

func test_rule_with_empty_name_is_skipped() -> void:
	save.felicidad = 90
	var rule := _make_rule("", "felicidad", 70.0, EmotionRule.Comparison.GREATER)
	var result := EmotionEngine.evaluate([rule], {"save": save})
	assert_eq(result.size(), 0)
