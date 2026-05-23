extends GutTest

var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()


# Busca dinámicamente seeds cuyo primer randf() caiga a cada lado de prob.
func _find_seeds(prob: float) -> Dictionary:
	var probe := RandomNumberGenerator.new()
	var seed_on := -1
	var seed_off := -1
	for s in range(5000):
		probe.seed = s
		var v := probe.randf()
		if seed_on == -1 and v < prob:
			seed_on = s
		if seed_off == -1 and v >= prob:
			seed_off = s
		if seed_on != -1 and seed_off != -1:
			break
	return {"on": seed_on, "off": seed_off}


# ── hungry ────────────────────────────────────────────────────────────────────

func test_hungry_dispara_con_hambre_maxima() -> void:
	save.hambre = 100  # prob=1.0, determinístico
	var rules: Array[EmotionRule] = [load("res://data/emotions/rules/hungry.tres")]
	assert_has(EmotionEngine.evaluate(rules, {"save": save}), "hungry")


func test_hungry_no_dispara_con_hambre_minima() -> void:
	save.hambre = 0  # prob=0.0, determinístico
	var rules: Array[EmotionRule] = [load("res://data/emotions/rules/hungry.tres")]
	assert_does_not_have(EmotionEngine.evaluate(rules, {"save": save}), "hungry")


func test_hungry_dispara_en_zona_probabilistica() -> void:
	save.hambre = 85
	var rule: EmotionRule = load("res://data/emotions/rules/hungry.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "hungry")


func test_hungry_no_dispara_en_zona_probabilistica() -> void:
	save.hambre = 85
	var rule: EmotionRule = load("res://data/emotions/rules/hungry.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "hungry")


# ── bathroom ──────────────────────────────────────────────────────────────────

func test_bathroom_dispara_con_ganas_maximas() -> void:
	save.ganas_bano = 100  # prob=1.0, determinístico
	var rules: Array[EmotionRule] = [load("res://data/emotions/rules/bathroom.tres")]
	assert_has(EmotionEngine.evaluate(rules, {"save": save}), "bathroom")


func test_bathroom_no_dispara_con_ganas_minimas() -> void:
	save.ganas_bano = 0  # prob=0.0, determinístico
	var rules: Array[EmotionRule] = [load("res://data/emotions/rules/bathroom.tres")]
	assert_does_not_have(EmotionEngine.evaluate(rules, {"save": save}), "bathroom")


func test_bathroom_dispara_en_zona_probabilistica() -> void:
	save.ganas_bano = 70
	var rule: EmotionRule = load("res://data/emotions/rules/bathroom.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "bathroom")


func test_bathroom_no_dispara_en_zona_probabilistica() -> void:
	save.ganas_bano = 70
	var rule: EmotionRule = load("res://data/emotions/rules/bathroom.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "bathroom")


# ── sick ──────────────────────────────────────────────────────────────────────

func test_sick_dispara_en_zona_probabilistica() -> void:
	save.salud = 15
	var rule: EmotionRule = load("res://data/emotions/rules/sick.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "sick")


func test_sick_no_dispara_en_zona_probabilistica() -> void:
	save.salud = 15
	var rule: EmotionRule = load("res://data/emotions/rules/sick.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "sick")


# ── tired ─────────────────────────────────────────────────────────────────────

func test_tired_dispara_en_zona_probabilistica() -> void:
	save.energia = 15
	var rule: EmotionRule = load("res://data/emotions/rules/tired.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "tired")


func test_tired_no_dispara_en_zona_probabilistica() -> void:
	save.energia = 15
	var rule: EmotionRule = load("res://data/emotions/rules/tired.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "tired")


# ── sad ───────────────────────────────────────────────────────────────────────

func test_sad_dispara_en_zona_probabilistica() -> void:
	save.felicidad = 10
	var rule: EmotionRule = load("res://data/emotions/rules/sad.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "sad")


func test_sad_no_dispara_en_zona_probabilistica() -> void:
	save.felicidad = 10
	var rule: EmotionRule = load("res://data/emotions/rules/sad.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "sad")


# ── stressed ──────────────────────────────────────────────────────────────────

func test_stressed_dispara_en_zona_probabilistica() -> void:
	save.estres = 80
	var rule: EmotionRule = load("res://data/emotions/rules/stressed.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "stressed")


func test_stressed_no_dispara_en_zona_probabilistica() -> void:
	save.estres = 80
	var rule: EmotionRule = load("res://data/emotions/rules/stressed.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "stressed")


# ── bored ─────────────────────────────────────────────────────────────────────

func test_bored_dispara_en_zona_probabilistica() -> void:
	save.aburrimiento = 90
	var rule: EmotionRule = load("res://data/emotions/rules/bored.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.on
	assert_has(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "bored")


func test_bored_no_dispara_en_zona_probabilistica() -> void:
	save.aburrimiento = 90
	var rule: EmotionRule = load("res://data/emotions/rules/bored.tres")
	var seeds := _find_seeds(rule.evaluate({"save": save}))
	var rng := RandomNumberGenerator.new()
	rng.seed = seeds.off
	assert_does_not_have(EmotionEngine.evaluate([rule], {"save": save, "rng": rng}), "bored")


# ── bloqueos por emocion ya activa ───────────────────────────────────────────

func test_hungry_activo_bloquea_bathroom() -> void:
	save.ganas_bano = 100  # bathroom querría activarse (prob=1.0)
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/hungry.tres"),
		load("res://data/emotions/rules/bathroom.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["hungry"]})
	assert_does_not_have(result, "bathroom")


func test_bathroom_activo_bloquea_hungry() -> void:
	save.hambre = 100  # hungry querría activarse (prob=1.0)
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/hungry.tres"),
		load("res://data/emotions/rules/bathroom.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["bathroom"]})
	assert_does_not_have(result, "hungry")


func test_sad_activo_bloquea_stressed() -> void:
	save.estres = 100
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/sad.tres"),
		load("res://data/emotions/rules/stressed.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["sad"]})
	assert_does_not_have(result, "stressed")


func test_sad_activo_bloquea_bored() -> void:
	save.aburrimiento = 100
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/sad.tres"),
		load("res://data/emotions/rules/bored.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["sad"]})
	assert_does_not_have(result, "bored")


func test_sick_activo_bloquea_sad() -> void:
	save.felicidad = 0
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/sick.tres"),
		load("res://data/emotions/rules/sad.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["sick"]})
	assert_does_not_have(result, "sad")


func test_sick_activo_bloquea_stressed() -> void:
	save.estres = 100
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/sick.tres"),
		load("res://data/emotions/rules/stressed.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["sick"]})
	assert_does_not_have(result, "stressed")


func test_sick_activo_bloquea_bored() -> void:
	save.aburrimiento = 100
	var rules: Array[EmotionRule] = [
		load("res://data/emotions/rules/sick.tres"),
		load("res://data/emotions/rules/bored.tres"),
	]
	var result := EmotionEngine.evaluate(rules, {"save": save, "active": ["sick"]})
	assert_does_not_have(result, "bored")
