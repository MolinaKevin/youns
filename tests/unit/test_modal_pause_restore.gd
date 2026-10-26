extends GutTest

const QuickMenuScene := preload("res://features/menus/quick_menu/quick_menu.tscn")
const SaveStationScript := preload("res://features/world/save_station/save_station.gd")

var _tree_was_paused := false
var _clock_was_paused := false


func before_each() -> void:
	_tree_was_paused = get_tree().paused
	_clock_was_paused = GameState.clock_paused
	get_tree().paused = false
	GameState.set_clock_paused(false)


func after_each() -> void:
	get_tree().paused = false
	GameState.set_clock_paused(_clock_was_paused)
	get_tree().paused = _tree_was_paused


func test_menu_rapido_restaura_las_pausas_que_encontro() -> void:
	var menu := QuickMenuScene.instantiate()
	add_child_autofree(menu)
	get_tree().paused = true
	GameState.set_clock_paused(true)

	menu.open()
	menu.close()

	assert_true(get_tree().paused)
	assert_true(GameState.clock_paused)


func test_estacion_de_guardado_restaura_las_pausas_que_encontro() -> void:
	var station := Node3D.new()
	station.set_script(SaveStationScript)
	add_child_autofree(station)
	get_tree().paused = true
	GameState.set_clock_paused(true)

	station.open_dialog()
	station.close_dialog()

	assert_true(get_tree().paused)
	assert_true(GameState.clock_paused)
