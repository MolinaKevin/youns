extends GutTest

# Tests de las cartas que escalan con estadísticas: valor = base + factor × stat.


func _scaling(base: int, stat: String, factor: float) -> StatScaling:
	var sc := StatScaling.new()
	sc.base = base
	sc.stat = stat
	sc.factor = factor
	return sc


func test_evaluate_es_base_mas_factor_por_stat() -> void:
	assert_eq(_scaling(30, "fuerza", 0.6).evaluate({"fuerza": 50}), 60)
	assert_eq(_scaling(30, "fuerza", 0.6).evaluate({"fuerza": 100}), 90)


func test_evaluate_sin_stat_es_solo_la_base() -> void:
	assert_eq(_scaling(25, "ninguna", 2.0).evaluate({"fuerza": 999}), 25)


func test_evaluate_stat_ausente_cuenta_como_cero() -> void:
	assert_eq(_scaling(10, "tecnica", 1.0).evaluate({}), 10)


func test_evaluate_nunca_es_negativo() -> void:
	assert_eq(_scaling(-50, "fuerza", 0.1).evaluate({"fuerza": 10}), 0)


func test_resolved_calcula_los_valores_escalados_y_respeta_los_fijos() -> void:
	var line := CardActionLine.new()
	line.card_type = "melee_attack"
	line.damage = 60
	line.card_range = 7
	line.damage_scaling = _scaling(30, "fuerza", 0.6)
	line.name = "Golpe"
	var r := line.resolved({"fuerza": 80})
	assert_eq(r.damage, 78)        # 30 + 0,6 × 80
	assert_eq(r.card_range, 7)     # sin escalado: fijo
	assert_eq(r.name, "Golpe")
	assert_eq(line.damage, 60)     # la línea original no cambia


func test_resolved_escala_bloqueo_movimiento_y_lanzamiento() -> void:
	var line := CardActionLine.new()
	line.block_scaling = _scaling(10, "resistencia", 0.5)
	line.range_scaling = _scaling(20, "agilidad", 0.4)
	line.throw_scaling = _scaling(40, "fuerza", 1.0)
	var r := line.resolved({"resistencia": 60, "agilidad": 50, "fuerza": 30})
	assert_eq(r.block_amount, 40)
	assert_eq(r.card_range, 40)
	assert_eq(r.throw_range, 70)


func test_cartas_con_stat_50_dan_su_valor_original() -> void:
	# Las fórmulas actuales son provisorias: a 50 (un rookie típico) cada línea
	# vale lo mismo que su valor fijo guardado.
	var stats := {}
	for key in YounStats.KEYS:
		stats[key] = 50
	for card: CardData in CardDatabase.cards_by_id.values():
		for half in [card.top, card.bottom]:
			for line: CardActionLine in half.lines:
				var r := line.resolved(stats)
				assert_eq(r.damage, line.damage, "%s daño" % card.id)
				assert_eq(r.block_amount, line.block_amount, "%s bloqueo" % card.id)
				assert_eq(r.card_range, line.card_range, "%s rango" % card.id)
				assert_eq(r.throw_range, line.throw_range, "%s lanzamiento" % card.id)
