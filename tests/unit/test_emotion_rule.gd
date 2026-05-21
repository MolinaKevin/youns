extends GutTest

var rule: EmotionRule
var save: PlayerSaveData


func before_each() -> void:
	rule = EmotionRule.new()
	save = PlayerSaveData.new()


# ── evaluate sin stat_key ─────────────────────────────────────────────────────

func test_evaluate_returns_zero_when_no_stat_key() -> void:
	rule.stat_key = ""
	var result := rule.evaluate({"save": save})
	assert_eq(result, 0.0)


func test_evaluate_returns_zero_when_no_save() -> void:
	rule.stat_key = "felicidad"
	var result := rule.evaluate({"save": null})
	assert_eq(result, 0.0)


# ── GREATER ───────────────────────────────────────────────────────────────────

func test_greater_returns_one_when_above_threshold() -> void:
	rule.stat_key = "felicidad"
	rule.comparison = EmotionRule.Comparison.GREATER
	rule.threshold = 70.0
	save.felicidad = 80
	assert_eq(rule.evaluate({"save": save}), 1.0)


func test_greater_returns_one_at_exact_threshold() -> void:
	rule.stat_key = "felicidad"
	rule.comparison = EmotionRule.Comparison.GREATER
	rule.threshold = 70.0
	save.felicidad = 70
	assert_eq(rule.evaluate({"save": save}), 1.0)


func test_greater_returns_zero_when_below_threshold() -> void:
	rule.stat_key = "felicidad"
	rule.comparison = EmotionRule.Comparison.GREATER
	rule.threshold = 70.0
	save.felicidad = 60
	assert_eq(rule.evaluate({"save": save}), 0.0)


# ── LESS ──────────────────────────────────────────────────────────────────────

func test_less_returns_one_when_below_threshold() -> void:
	rule.stat_key = "estres"
	rule.comparison = EmotionRule.Comparison.LESS
	rule.threshold = 30.0
	save.estres = 20
	assert_eq(rule.evaluate({"save": save}), 1.0)


func test_less_returns_zero_when_above_threshold() -> void:
	rule.stat_key = "estres"
	rule.comparison = EmotionRule.Comparison.LESS
	rule.threshold = 30.0
	save.estres = 50
	assert_eq(rule.evaluate({"save": save}), 0.0)


# ── BOOL_TRUE ─────────────────────────────────────────────────────────────────

func test_bool_true_returns_one_for_true_bool() -> void:
	rule.stat_key = "enfermo"
	rule.comparison = EmotionRule.Comparison.BOOL_TRUE
	save.enfermo = true
	assert_eq(rule.evaluate({"save": save}), 1.0)


func test_bool_true_returns_zero_for_false_bool() -> void:
	rule.stat_key = "enfermo"
	rule.comparison = EmotionRule.Comparison.BOOL_TRUE
	save.enfermo = false
	assert_eq(rule.evaluate({"save": save}), 0.0)


# ── stat inexistente ──────────────────────────────────────────────────────────

func test_unknown_stat_key_returns_zero() -> void:
	rule.stat_key = "stat_que_no_existe"
	rule.comparison = EmotionRule.Comparison.GREATER
	rule.threshold = 10.0
	assert_eq(rule.evaluate({"save": save}), 0.0)
