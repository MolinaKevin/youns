extends GutTest

# Campeones y ultimates de prueba: a quién se llega según las condiciones.

const D := "res://data/youns/"
const CHAMPIONS := ["pillan", "yaguarete_aba", "caa_pora", "kalku"]

var _day: int
var _hour: float


var _zone := ""


func before_each() -> void:
	# Zona fija que ninguna condición usa: los tests no dependen de dónde quedó el jugador.
	_zone = ZoneManager.current_zone
	ZoneManager.enter_zone("crossroads")
	_day = GameState.current_day
	_hour = GameState.time_of_day_hours
	GameState.current_day = 10
	GameState.time_of_day_hours = 14.0


func after_each() -> void:
	ZoneManager.enter_zone(_zone)
	GameState.current_day = _day
	GameState.time_of_day_hours = _hour


func _youn(id: String) -> YounData:
	return load(D + id + ".tres")


func _save(youn_id: String, days_in_stage: float) -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.current_youn_path = D + youn_id + ".tres"
	save.stage_entered_total_hour = GameState.get_total_hours() - days_in_stage * 24.0
	YounStatRules.start_life(save, _youn(youn_id))
	return save


func test_hay_5_campeones_y_2_ultimates() -> void:
	var champions := EvolutionChecker.stage_candidates("campeon")
	assert_eq(champions.size(), 4, "4 campeones normales")
	assert_true(_youn("mboi_tui").is_wildcard, "más el comodín")
	assert_eq(_youn("arasy").stage, "ultimate")
	assert_eq(_youn("luison").stage, "ultimate")


func test_cada_campeon_y_ultimate_tiene_5_condiciones() -> void:
	for id in CHAMPIONS + ["arasy", "luison"]:
		assert_eq(_youn(id).evolution_conditions.size(), 5, id)
	assert_eq(_youn("mboi_tui").evolution_conditions.size(), 0, "el comodín no tiene")


func test_pombero_bien_cuidado_va_a_yaguarete_aba() -> void:
	# Inteligencia corporal + viene de Pombero + pocos errores de cuidado = 3.
	var save := _save("pombero", 3.1)
	save.care_mistakes = 0
	assert_eq(EvolutionChecker.try_evolve(save, _youn("pombero")), D + "yaguarete_aba.tres")


func test_sin_3_condiciones_va_al_comodin() -> void:
	var save := _save("pombero", 3.1)
	save.care_mistakes = 5
	assert_eq(EvolutionChecker.try_evolve(save, _youn("pombero")), D + "mboi_tui.tres")


func test_el_campeon_pasa_a_ultimate_en_cuanto_cumple_3() -> void:
	# Pillán con espíritu 120 y felicidad 80 (intel naturalista cumple) = 3.
	var save := _save("pillan", 1.0)
	save.youn_stats["espiritu"] = 120
	save.felicidad = 80
	assert_eq(EvolutionChecker.try_evolve(save, _youn("pillan")), D + "arasy.tres")


func test_el_campeon_sin_condiciones_no_evoluciona_antes_de_tiempo() -> void:
	var save := _save("pillan", 1.0)
	save.youn_stats["espiritu"] = 10
	save.felicidad = 10
	assert_eq(EvolutionChecker.try_evolve(save, _youn("pillan")), "")


func test_el_campeon_al_terminar_su_vida_reencarna_aunque_tenga_ultimates() -> void:
	var save := _save("pillan", 6.5)
	save.youn_stats["espiritu"] = 10
	save.felicidad = 10
	assert_eq(EvolutionChecker.try_evolve(save, _youn("pillan")), EvolutionChecker.REINCARNATE)


func test_el_comodin_descuidado_llega_a_luison() -> void:
	# Viene de Mbói Tu'i + fuerza 110 + 3 errores de cuidado = 3.
	var save := _save("mboi_tui", 1.0)
	save.youn_stats["fuerza"] = 110
	save.care_mistakes = 3
	assert_eq(EvolutionChecker.try_evolve(save, _youn("mboi_tui")), D + "luison.tres")


func test_luison_es_exclusivo_del_comodin() -> void:
	for id in CHAMPIONS:
		assert_false((D + "luison.tres") in _youn(id).evolves_to, id)
	assert_eq(_youn("mboi_tui").evolves_to, [D + "luison.tres"] as Array[String])
