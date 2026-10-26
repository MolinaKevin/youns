extends GutTest

# apply_stat_decay corre con GameState.twenty_min_ticked (3 veces por hora):
# en una hora de juego cada stat tiene que moverse exactamente su rate_per_hour.
const Youn3DScript := preload("res://features/world/party/youn_3d.gd")

var _save_backup: PlayerSaveData
var _youn_backup: Node
var _test_youn: CharacterBody3D


func before_each() -> void:
	_save_backup = GameState.player_save
	GameState.player_save = PlayerSaveData.new()
	StatsManager.restore_from_save(GameState.player_save)
	_youn_backup = PartyManager.youn
	PartyManager.youn = null


func after_each() -> void:
	GameState.player_save = _save_backup
	StatsManager.restore_from_save(_save_backup)
	PartyManager.youn = _youn_backup
	if is_instance_valid(_test_youn):
		_test_youn.free()
	_test_youn = null


func _run_hours(hours: int) -> void:
	for i in hours * 3:
		StatsManager.apply_stat_decay()


func _rate(stat_key: String) -> float:
	return (load("res://data/stats/%s.tres" % stat_key) as StatConfig).rate_per_hour


func test_una_hora_sube_el_hambre_su_rate_por_hora() -> void:
	GameState.player_save.hambre = 0
	_run_hours(1)
	assert_eq(GameState.player_save.hambre, int(_rate("hambre")))


func test_dos_horas_bajan_la_felicidad_el_doble_del_rate() -> void:
	# felicidad tiene rate fraccionario (-1.5): el acumulador no pierde decimales
	GameState.player_save.felicidad = 50
	_run_hours(2)
	assert_eq(GameState.player_save.felicidad, 50 + int(_rate("felicidad") * 2))


func test_cada_stat_se_mueve_su_rate_en_seis_horas() -> void:
	for key in ["hambre", "aburrimiento", "ganas_bano", "energia"]:
		GameState.player_save.set(key, 50)
	_run_hours(6)
	for key in ["hambre", "aburrimiento", "ganas_bano", "energia"]:
		assert_eq(GameState.player_save.get(key), 50 + int(_rate(key) * 6), key)


func test_decay_respeta_el_multiplicador_del_youn() -> void:
	var data := YounData.new()
	data.mult_energia = 2.0
	_test_youn = Youn3DScript.new()
	_test_youn.set("youn_data", data)
	PartyManager.youn = _test_youn
	GameState.player_save.energia = 50
	_run_hours(1)
	assert_eq(GameState.player_save.energia, 50 + int(_rate("energia") * data.mult_energia))
