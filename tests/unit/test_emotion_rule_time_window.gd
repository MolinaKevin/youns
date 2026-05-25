extends GutTest

# EmotionRuleTimeWindow: retorna 1.0 si la hora actual cae dentro de la ventana
# de sueño del Youn, 0.0 si está fuera.


func _make_youn(sleep: int, wake: int) -> YounData:
	var y := YounData.new()
	y.sleep_hour = sleep
	y.wake_hour  = wake
	return y


func _eval(sleep: int, wake: int, hour: float) -> float:
	GameState.time_of_day_hours = hour
	var rule := EmotionRuleTimeWindow.new()
	return rule.evaluate({"youn_data": _make_youn(sleep, wake)})


# ── sin youn_data ─────────────────────────────────────────────────────────────

func test_sin_youn_data_retorna_cero() -> void:
	GameState.time_of_day_hours = 10.0
	assert_almost_eq(EmotionRuleTimeWindow.new().evaluate({}), 0.0, 0.01)


# ── ventana que cruza medianoche (sleep_hour > wake_hour) ─────────────────────
# Ejemplo: duerme a las 22, despierta a las 7

func test_hora_dentro_de_ventana_nocturna_retorna_uno() -> void:
	assert_almost_eq(_eval(22, 7, 23.0), 1.0, 0.01)


func test_hora_madrugada_dentro_de_ventana_retorna_uno() -> void:
	assert_almost_eq(_eval(22, 7, 3.0), 1.0, 0.01)


func test_hora_exacta_de_inicio_de_sueño_retorna_uno() -> void:
	assert_almost_eq(_eval(22, 7, 22.0), 1.0, 0.01)


func test_hora_fuera_de_ventana_nocturna_retorna_cero() -> void:
	assert_almost_eq(_eval(22, 7, 10.0), 0.0, 0.01)


func test_hora_exacta_de_despertar_no_cuenta_como_dormido() -> void:
	assert_almost_eq(_eval(22, 7, 7.0), 0.0, 0.01)


# ── ventana normal (sleep_hour < wake_hour) ───────────────────────────────────
# Ejemplo: siesta de 14 a 16

func test_hora_dentro_de_ventana_normal_retorna_uno() -> void:
	assert_almost_eq(_eval(14, 16, 15.0), 1.0, 0.01)


func test_hora_fuera_de_ventana_normal_retorna_cero() -> void:
	assert_almost_eq(_eval(14, 16, 18.0), 0.0, 0.01)


func test_hora_exacta_de_fin_de_ventana_normal_no_cuenta() -> void:
	assert_almost_eq(_eval(14, 16, 16.0), 0.0, 0.01)
