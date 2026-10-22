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


func test_evaluate_suma_la_segunda_stat_y_el_peso() -> void:
	var sc := _scaling(30, "constitucion", 0.5)
	sc.stat_2 = "peso"
	sc.factor_2 = 2.5
	assert_eq(sc.evaluate({"constitucion": 50, "peso": 10.0}), 80)
	assert_eq(sc.evaluate({"constitucion": 50, "peso": 14.0}), 90)


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


func test_movimiento_modular_convierte_modulos_a_celdas() -> void:
	var line := CardActionLine.new()
	line.card_type = "move"
	line.movement_base_modules = 3
	assert_eq(line.movement_range_cells(), 24)
	assert_eq(line.movement_module_label(), "3")


func test_movimiento_modular_suma_modulos_y_aplica_multiplicador() -> void:
	var line := CardActionLine.new()
	line.card_type = "move"
	line.movement_base_modules = 3
	line.movement_extra_modules = 1
	line.movement_stat_multiplier = 1.5
	assert_eq(line.movement_range_cells(), 48)
	assert_eq(line.movement_module_label(), "6")


func test_movimiento_heredado_se_convierte_a_modulos() -> void:
	var line := CardActionLine.new()
	line.card_type = "move"
	line.card_range = 38
	assert_eq(line.movement_modules(), 5)
	assert_eq(line.movement_range_cells(), 40)


func test_patron_heredado_convierte_alcance_y_lanzamiento_a_modulos() -> void:
	var line := CardActionLine.new()
	line.card_range = 13
	line.throw_range = 38
	assert_eq(line.primary_modules(), 2)
	assert_eq(line.primary_range_cells(), 16)
	assert_eq(line.cast_modules(), 5)
	assert_eq(line.cast_range_cells(), 40)


func test_patron_modular_aplica_extra_y_multiplicador() -> void:
	var line := CardActionLine.new()
	line.primary_base_modules = 3
	line.primary_extra_modules = 1
	line.primary_stat_multiplier = 1.5
	assert_eq(line.primary_range_cells(), 48)
	assert_eq(line.primary_module_label(), "6")


func test_rango_modular_conserva_el_escalado_heredado() -> void:
	var scaling := StatScaling.new()
	scaling.base = 18
	scaling.stat = "agilidad"
	scaling.factor = 0.4
	var line := CardActionLine.new()
	line.card_type = "move"
	line.movement_base_modules = 5
	line.range_scaling = scaling
	var resolved := line.resolved({"agilidad": 0})
	# 18 celdas se redondeaba antes a 2 módulos; la migración mantiene eso.
	assert_eq(resolved.movement_range_cells(), 16)


func test_patron_reutilizable_indica_si_necesita_direccion() -> void:
	var pattern := CardPattern.new()
	pattern.shape = "line"
	pattern.direction = "cursor"
	assert_true(pattern.needs_direction())
	pattern.shape = "circle"
	assert_false(pattern.needs_direction())


func test_acciones_espaciales_tienen_patron_declarado() -> void:
	var expected := {
		"charco": "circle",
		"chispa": "circle",
		"granizada": "circle",
		"grenade": "circle",
		"bear_trap": "circle",
		"envion": "line",
		"ancla": "line",
		"descarga": "line",
		"golpe_de_roca": "cone",
		"emboscada": "cone",
	}
	for card_id: String in expected:
		var card: CardData = CardDatabase.cards_by_id[card_id]
		var spatial_line: CardActionLine = null
		for half in [card.top, card.bottom]:
			for line: CardActionLine in half.lines:
				if line.card_type != "move":
					spatial_line = line
					break
			if spatial_line != null:
				break
		assert_not_null(spatial_line, "%s tiene una acción espacial" % card_id)
		assert_not_null(spatial_line.pattern, "%s declara CardPattern" % card_id)
		assert_eq(spatial_line.pattern.shape, expected[card_id], "%s usa la forma correcta" % card_id)


func test_cartas_con_stat_50_dan_su_valor_original() -> void:
	# Las fórmulas actuales son provisorias: a 50 (un rookie típico) cada línea
	# vale lo mismo que su valor fijo guardado.
	var stats := {}
	for key in YounStats.KEYS:
		stats[key] = 50
	stats["peso"] = 10.0  # peso base típico (YounData.base_weight)
	for card: CardData in CardDatabase.cards_by_id.values():
		for half in [card.top, card.bottom]:
			for line: CardActionLine in half.lines:
				var r := line.resolved(stats)
				assert_eq(r.damage, line.damage, "%s daño" % card.id)
				assert_eq(r.block_amount, line.block_amount, "%s bloqueo" % card.id)
				assert_eq(r.card_range, line.card_range, "%s rango" % card.id)
				assert_eq(r.throw_range, line.throw_range, "%s lanzamiento" % card.id)
				assert_eq(r.restore_amount, line.restore_amount, "%s recuperación" % card.id)
				assert_eq(r.duration, line.duration, "%s duración" % card.id)
				assert_eq(r.module_count, line.module_count, "%s módulos" % card.id)
