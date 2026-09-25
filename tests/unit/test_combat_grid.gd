extends GutTest

# Tests de la grilla del combate: conversión, alcance (8 direcciones, diagonal 1,41) y caminos.


func _always(_c: Vector2i) -> bool:
	return true


func test_to_world_devuelve_el_centro_de_la_casilla() -> void:
	var w := CombatGrid.to_world(Vector2i(2, 3))
	assert_almost_eq(w.x, 2.5 * CombatGrid.CELL, 0.0001)
	assert_almost_eq(w.y, 3.5 * CombatGrid.CELL, 0.0001)


func test_to_cell_y_to_world_son_inversas() -> void:
	var cell := Vector2i(17, 42)
	assert_eq(CombatGrid.to_cell(CombatGrid.to_world(cell)), cell)


func test_reachable_diagonal_cuesta_1_41() -> void:
	var reach := CombatGrid.reachable(Vector2i.ZERO, 3, _always)
	assert_almost_eq(reach[Vector2i(1, 1)]["cost"], 1.41, 0.001)
	assert_almost_eq(reach[Vector2i(1, 2)]["cost"], 2.41, 0.001)  # 1 diagonal + 1 recto


func test_reachable_alcance_casi_circular() -> void:
	var reach := CombatGrid.reachable(Vector2i.ZERO, 10, _always)
	assert_true(reach.has(Vector2i(10, 0)))
	assert_true(reach.has(Vector2i(7, 7)))    # 7 * 1,41 = 9,87 (en cruz serían 14)
	assert_false(reach.has(Vector2i(8, 8)))   # 11,28
	assert_false(reach.has(Vector2i(11, 0)))


func test_reachable_no_corta_esquinas_en_diagonal() -> void:
	# Bloqueadas (1, 0) y (0, 1): la diagonal a (1, 1) pasaría por la esquina.
	var passable := func(c: Vector2i) -> bool: return c != Vector2i(1, 0) and c != Vector2i(0, 1)
	var reach := CombatGrid.reachable(Vector2i.ZERO, 1, passable)
	assert_false(reach.has(Vector2i(1, 1)))


func test_reachable_rodea_obstaculos() -> void:
	# Pared en x = 1 salvo el hueco en y = 2.
	var passable := func(c: Vector2i) -> bool: return c.x != 1 or c.y == 2
	var reach := CombatGrid.reachable(Vector2i.ZERO, 6, passable)
	assert_false(reach.has(Vector2i(1, 0)))
	assert_true(reach.has(Vector2i(2, 0)))
	# Rodeando por el hueco: más caro que la línea recta (2).
	assert_gt(reach[Vector2i(2, 0)]["cost"], 2.0)


func test_path_to_va_en_diagonal_cuando_es_mas_corto() -> void:
	var reach := CombatGrid.reachable(Vector2i.ZERO, 4, _always)
	var path := CombatGrid.path_to(reach, Vector2i(2, 2))
	assert_eq(path, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)] as Array[Vector2i])


func test_octile_combina_rectos_y_diagonales() -> void:
	assert_almost_eq(CombatGrid.octile(Vector2i(3, 1)), 3.41, 0.001)
	assert_almost_eq(CombatGrid.octile(Vector2i(-2, 2)), 2.82, 0.001)


func test_path_to_meta_inalcanzable_devuelve_vacio() -> void:
	var reach := CombatGrid.reachable(Vector2i.ZERO, 1, _always)
	assert_true(CombatGrid.path_to(reach, Vector2i(5, 5)).is_empty())


func test_corners_deja_solo_los_quiebres() -> void:
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)]
	assert_eq(CombatGrid.corners(path), [Vector2i(0, 0), Vector2i(2, 0), Vector2i(2, 2)] as Array[Vector2i])
