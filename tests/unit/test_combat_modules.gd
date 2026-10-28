extends "res://tests/helpers/combat_test_case.gd"

## Pruebas de módulos y obstáculos construibles.
const MapAreaScript := preload("res://features/combat/scene/map_area.gd")
const BoardFixture := preload("res://tests/helpers/combat_board_fixture.gd")

func test_romper_modulo_libera_el_paso() -> void:
	var map = MapAreaScript.new()
	var rock: Dictionary = map.obstacles.modules.module_at(Vector2(15.0, 15.0))
	assert_eq(rock.get("type"), "rock")
	assert_true(map.terrain.geometry.collision.is_blocked(Vector2(15.0, 15.0)))
	assert_eq(map.obstacles.modules.break_modules(rock, 1), 1)
	assert_false(map.terrain.geometry.collision.is_blocked(Vector2(15.0, 15.0)))
	assert_true(map.obstacles.modules.module_at(Vector2(15.0, 15.0)).is_empty())
	map.free()


func test_paredes_puentes_y_plataformas_no_son_modulos() -> void:
	var map = MapAreaScript.new()
	assert_true(map.obstacles.modules.module_at(Vector2(14.0, 19.0)).is_empty())  # pared
	assert_true(map.obstacles.modules.module_at(Vector2(13.0, 24.0)).is_empty())  # puente
	assert_true(map.obstacles.modules.module_at(Vector2(8.0, 10.0)).is_empty())   # plataforma
	map.free()


func _map_for_modules():
	return BoardFixture.empty_modules_map()


func test_muro_levanta_modulos_en_fila_perpendicular() -> void:
	var map = _map_for_modules()
	assert_eq(map.obstacles.modules.build_modules(Vector2(10, 15), 3), 3)
	var ys := []
	for obs in map.terrain.obstacles():
		assert_eq(obs["pos"].x, 10.0)
		ys.append(obs["pos"].y)
	ys.sort()
	assert_eq(ys, [14.0, 15.0, 16.0])
	assert_true(map.terrain.geometry.collision.is_blocked(Vector2(10, 15)))
	map.free()


func test_muro_no_se_levanta_encima_de_un_actor() -> void:
	var map = _map_for_modules()
	assert_eq(map.obstacles.modules.build_modules(Vector2(28, 15), 1), 0)
	map.free()


func test_romper_varios_modulos_pegados() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(10, 15), 3)
	map.obstacles.modules.build_modules(Vector2(20, 15), 1)  # lejos: no está pegado
	var middle: Dictionary = map.obstacles.modules.module_at(Vector2(10, 15))
	assert_eq(map.obstacles.modules.break_modules(middle, 5), 3)
	assert_eq(map.terrain.obstacles().size(), 1)
	map.free()


func test_golpear_modulo_choca_al_enemigo() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.terrain.obstacles()[0]
	var result: Dictionary = map.obstacles.modules.slide_module(module, Vector2.RIGHT, 30.0)
	assert_eq(result["hit"], "enemy")
	assert_lt(result["pos"].x, 28.0 - map.actors.state.geometry.enemy_radius())
	map.free()


func test_golpear_modulo_sin_choque_recorre_su_distancia() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(10, 15), 1)
	var result: Dictionary = map.obstacles.modules.slide_module(map.terrain.obstacles()[0], Vector2.RIGHT, 5.0)
	assert_eq(result["hit"], "")
	assert_almost_eq(result["pos"].x, 15.0, 0.001)
	map.free()


func test_golpear_modulo_se_frena_en_otro_obstaculo() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(10, 15), 1)
	var module: Dictionary = map.terrain.obstacles()[0]
	map.obstacles.modules.build_modules(Vector2(14, 15), 1)
	var result: Dictionary = map.obstacles.modules.slide_module(module, Vector2.RIGHT, 10.0)
	assert_eq(result["hit"], "")
	assert_lt(result["pos"].x, 13.0 + 0.001)
	map.free()


func test_derrumbe_tira_solo_los_modulos_pegados_al_enemigo() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(26.6, 15), 1)  # pegado al enemigo (28, 15)
	map.obstacles.modules.build_modules(Vector2(28, 13.6), 1)  # pegado
	map.obstacles.modules.build_modules(Vector2(24, 15), 1)    # lejos
	assert_eq(map.obstacles.modules.modules_adjacent_to_enemy().size(), 2)
	assert_eq(map.obstacles.modules.collapse_modules_on_enemy(), 2)
	assert_eq(map.terrain.obstacles().size(), 1)
	map.free()


func test_muro_que_pasa_por_encima_del_enemigo_queda_pegado_para_derrumbe() -> void:
	var map = _map_for_modules()
	map.player_pos = Vector2(28, 25)
	# Muro de 5 que cruza al enemigo (28, 15): los del medio se saltean.
	map.obstacles.modules.build_modules(Vector2(28.5, 15), 5)
	assert_lt(map.terrain.obstacles().size(), 5)
	assert_eq(map.obstacles.modules.modules_adjacent_to_enemy().size(), 2)
	map.free()


func test_lanzar_modulo_le_cae_al_enemigo_y_se_rompe() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(4, 15), 1)
	var module: Dictionary = map.terrain.obstacles()[0]
	var hits: Dictionary = map.obstacles.modules.throw_module(module, Vector2(27.5, 15))
	assert_true(hits["enemy"])
	assert_false(hits["player"])
	assert_true(map.terrain.obstacles().is_empty())
	map.free()


func test_lanzar_modulo_al_vacio_no_le_pega_a_nadie() -> void:
	var map = _map_for_modules()
	map.obstacles.modules.build_modules(Vector2(4, 15), 1)
	var hits: Dictionary = map.obstacles.modules.throw_module(map.terrain.obstacles()[0], Vector2(15, 5))
	assert_false(hits["enemy"])
	assert_false(hits["player"])
	map.free()


