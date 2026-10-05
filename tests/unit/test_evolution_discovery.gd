extends GutTest

# Revelación progresiva de condiciones de evolución (EvolutionDiscovery).

var target: YounData
var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()
	target = YounData.new()
	target.id = "campeon_de_prueba"
	var stats := EvolutionConditionValues.new()
	stats.kind = EvolutionCondition.Kind.STATS
	var check := EvolutionValueCheck.new()
	check.key = "fuerza"
	check.min_value = 100
	stats.checks = [check]
	var intel := EvolutionConditionIntelligence.new()
	intel.intelligences = PackedStringArray(["corporal", "naturalista"])
	var hour := EvolutionConditionHour.new()
	# 0: stats, 1: inteligencia, 2: horario
	target.evolution_conditions = [stats, intel, hour]


## Evoluciona a `target` una vez sin cumplir nada: solo lo desbloquea.
func _unlock() -> void:
	EvolutionDiscovery.discover(save, target, [])


func test_primera_vez_con_inteligencia_cumplida_la_revela() -> void:
	var r := EvolutionDiscovery.discover(save, target, [0, 1, 2])
	assert_true(r["first_time"])
	assert_eq(r["revealed"], 1)
	assert_true(r["revealed_met"])


func test_primera_vez_sin_inteligencia_solo_desbloquea() -> void:
	var r := EvolutionDiscovery.discover(save, target, [0, 2])
	assert_true(r["first_time"])
	assert_eq(r["revealed"], -1)
	assert_eq(r["known"], [])
	assert_true(save.discovered_evolutions.has("campeon_de_prueba"))


func test_segunda_vez_revela_primero_la_inteligencia_cumplida() -> void:
	_unlock()
	var r := EvolutionDiscovery.discover(save, target, [0, 1, 2])
	assert_false(r["first_time"])
	assert_eq(r["revealed"], 1)


func test_segunda_vez_revela_una_cumplida_antes_que_una_no_cumplida() -> void:
	_unlock()
	var r := EvolutionDiscovery.discover(save, target, [2])
	assert_eq(r["revealed"], 2)
	assert_true(r["revealed_met"])


func test_sin_cumplidas_por_descubrir_revela_una_no_cumplida() -> void:
	_unlock()
	var r := EvolutionDiscovery.discover(save, target, [])
	assert_ne(r["revealed"], -1)
	assert_false(r["revealed_met"])


func test_entre_no_cumplidas_tambien_va_primero_la_inteligencia() -> void:
	_unlock()
	var r := EvolutionDiscovery.discover(save, target, [])
	assert_eq(r["revealed"], 1)


func test_siempre_avanza_aunque_no_se_cumpla_nada() -> void:
	# desbloqueo + 3 evoluciones sin cumplir nada = las 3 conocidas
	_unlock()
	for i in 3:
		EvolutionDiscovery.discover(save, target, [])
	var r := EvolutionDiscovery.discover(save, target, [])
	assert_eq(r["known"].size(), 3)
	assert_eq(r["revealed"], -1)


func test_lo_descubierto_queda_en_la_partida() -> void:
	_unlock()
	EvolutionDiscovery.discover(save, target, [0, 1])
	assert_eq(save.discovered_evolutions["campeon_de_prueba"], [1])


func test_met_indices_evalua_las_condiciones() -> void:
	var from := YounData.new()
	from.intelligences = PackedStringArray(["corporal"])
	save.youn_stats = {"fuerza": 150}
	var met := EvolutionDiscovery.met_indices(target, {"save": save, "from": from, "hour": 12.0})
	assert_eq(met, [0, 1] as Array[int])


func test_descripciones_automaticas() -> void:
	assert_string_contains(target.evolution_conditions[1].describe(), "Corporal")
	assert_string_contains(target.evolution_conditions[0].describe(), "100")


func test_la_descripcion_escrita_a_mano_tiene_prioridad() -> void:
	target.evolution_conditions[2].description = "Evolucionar de noche."
	assert_eq(target.evolution_conditions[2].describe(), "Evolucionar de noche.")


# ── rookies: una condición por stat dominante ─────────────────────────────────

func test_los_rookies_tienen_una_condicion_por_stat_dominante() -> void:
	for path in ["res://data/youns/pombero.tres", "res://data/youns/nguruvilu.tres"]:
		var rookie: YounData = load(path)
		assert_eq(rookie.evolution_conditions.size(), 4, path)
		var stats := []
		for condition in rookie.evolution_conditions:
			assert_true(condition is EvolutionConditionDominantStat, path)
			stats.append(condition.stat)
		assert_eq(PackedStringArray(stats), rookie.dominant_stats, path)


func test_se_cumple_solo_la_de_la_stat_mas_alta() -> void:
	var nguruvilu: YounData = load("res://data/youns/nguruvilu.tres")
	save.youn_stats = {"espiritu": 90, "constitucion": 50, "resistencia": 50, "fuerza": 50,
		"mente": 40, "agilidad": 40, "tecnica": 40, "inteligencia": 40}
	var met := EvolutionDiscovery.met_indices(nguruvilu, {"save": save})
	assert_eq(met, [0] as Array[int])


func test_descripcion_de_stat_dominante() -> void:
	var nguruvilu: YounData = load("res://data/youns/nguruvilu.tres")
	assert_eq(nguruvilu.evolution_conditions[0].describe(), "Espíritu como stat dominante")


# ── rookies: siempre y solo la cumplida ──────────────────────────────────────

func _rookie() -> YounData:
	return load("res://data/youns/nguruvilu.tres")


func test_rookie_la_primera_vez_revela_la_cumplida() -> void:
	var r := EvolutionDiscovery.discover(save, _rookie(), [2])
	assert_true(r["first_time"])
	assert_eq(r["revealed"], 2)
	assert_true(r["revealed_met"])


func test_rookie_con_la_misma_cumplida_no_revela_nada_nuevo() -> void:
	EvolutionDiscovery.discover(save, _rookie(), [2])
	var r := EvolutionDiscovery.discover(save, _rookie(), [2])
	assert_eq(r["revealed"], -1)
	assert_eq(r["known"], [2])


func test_rookie_nunca_revela_una_no_cumplida() -> void:
	EvolutionDiscovery.discover(save, _rookie(), [])
	var r := EvolutionDiscovery.discover(save, _rookie(), [])
	assert_eq(r["revealed"], -1)
	assert_eq(r["known"], [])


func test_rookie_con_otra_stat_dominante_revela_esa() -> void:
	EvolutionDiscovery.discover(save, _rookie(), [2])
	var r := EvolutionDiscovery.discover(save, _rookie(), [0])
	assert_eq(r["revealed"], 0)


func test_rookie_con_empate_revela_una_sola() -> void:
	var r := EvolutionDiscovery.discover(save, _rookie(), [1, 3])
	assert_true(r["revealed"] in [1, 3])
	assert_eq(r["known"].size(), 1)
	# la siguiente vez con el mismo empate revela la otra
	var r2 := EvolutionDiscovery.discover(save, _rookie(), [1, 3])
	assert_eq(r2["known"].size(), 2)


# ── niños: "evolucionar desde" el bebé ───────────────────────────────────────

func test_el_nino_tiene_una_condicion_evolucionar_desde_su_bebe() -> void:
	var nino: YounData = load("res://data/youns/nino_1.tres")
	assert_eq(nino.evolution_conditions.size(), 1)
	assert_true(nino.evolution_conditions[0] is EvolutionConditionFromYoun)
	assert_eq(nino.evolution_conditions[0].describe(), "Evolucionar desde Bebé 1")


func test_evolucionar_desde_el_bebe_se_cumple() -> void:
	var nino: YounData = load("res://data/youns/nino_1.tres")
	var bebe: YounData = load("res://data/youns/bebe_1.tres")
	assert_eq(EvolutionDiscovery.met_indices(nino, {"save": save, "from": bebe}), [0] as Array[int])
	var otro: YounData = load("res://data/youns/pombero.tres")
	assert_eq(EvolutionDiscovery.met_indices(nino, {"save": save, "from": otro}), [] as Array[int])


func test_el_nino_se_revela_la_primera_vez() -> void:
	var nino: YounData = load("res://data/youns/nino_1.tres")
	var r := EvolutionDiscovery.discover(save, nino, [0])
	assert_true(r["first_time"])
	assert_eq(r["revealed"], 0)

