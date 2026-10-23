extends GutTest

# Decoración desde meshes guía (AutoForest_/AutoGround_/NoAutoFill_/NoAutoTrees_).

const Deco := preload("res://features/world/zones/auto_decoration.gd")


func _square(x0: float, z0: float, size: float, y: float) -> PackedVector3Array:
	var a := Vector3(x0, y, z0)
	var b := Vector3(x0 + size, y, z0)
	var c := Vector3(x0 + size, y, z0 + size)
	var d := Vector3(x0, y, z0 + size)
	return PackedVector3Array([a, b, c, a, c, d])


func _area(tris: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(0, tris.size(), 3):
		var u := tris[i + 1] - tris[i]
		var v := tris[i + 2] - tris[i]
		total += absf(u.x * v.z - u.z * v.x) * 0.5
	return total


func _inside(p: Vector3, x0: float, z0: float, size: float) -> bool:
	return p.x > x0 and p.x < x0 + size and p.z > z0 and p.z < z0 + size


func test_los_arboles_van_sobre_la_guia_a_su_altura() -> void:
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 5.0))
	var trees: Array[Vector3] = deco.tree_positions(null, 0, 3.2, 1)
	assert_gt(trees.size(), 40)
	for p in trees:
		assert_almost_eq(p.y, 5.0, 0.01)
	assert_almost_eq(_area(deco.ground_triangles()), 900.0, 0.5, "el suelo es la guía misma")


func test_no_hay_arboles_en_el_borde_de_la_guia() -> void:
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	for p in deco.tree_positions(null, 0, 3.2, 1):
		assert_true(p.x >= 1.5 and p.x <= 28.5 and p.z >= 1.5 and p.z <= 28.5, "árbol en el borde en %s" % p)


func test_no_auto_trees_saca_arboles_pero_deja_suelo() -> void:
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	deco.add_triangles(Deco.Kind.NO_TREES, _square(10, 10, 10, 0.5))
	for p in deco.tree_positions(null, 0, 3.2, 1):
		assert_false(_inside(p, 10, 10, 10), "árbol en %s" % p)
	assert_almost_eq(_area(deco.ground_triangles()), 900.0, 0.5)


func test_no_auto_fill_saca_suelo_y_arboles() -> void:
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	deco.add_triangles(Deco.Kind.NO_FILL, _square(10, 10, 10, 0.0))
	for p in deco.tree_positions(null, 0, 3.2, 1):
		assert_false(_inside(p, 10, 10, 10), "árbol en %s" % p)
	assert_almost_eq(_area(deco.ground_triangles()), 800.0, 12.0, "el hueco sigue la forma del NoAutoFill")


func test_una_exclusion_a_otra_altura_no_afecta() -> void:
	var a = Deco.new()
	a.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	var b = Deco.new()
	b.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	b.add_triangles(Deco.Kind.NO_FILL, _square(0, 0, 30, -24.0))   # la playa de abajo
	assert_eq(b.tree_positions(null, 0, 3.2, 1).size(), a.tree_positions(null, 0, 3.2, 1).size())
	assert_almost_eq(_area(b.ground_triangles()), 900.0, 0.5)


func test_auto_ground_no_lleva_arboles() -> void:
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.GROUND, _square(0, 0, 30, 0.0))
	assert_eq(deco.tree_positions(null, 0, 3.2, 1).size(), 0)
	assert_almost_eq(_area(deco.ground_triangles()), 900.0, 0.5)


func test_no_planta_sobre_lo_caminable_ni_pegado() -> void:
	var grid := WorldBoundaryGrid.new()
	grid.setup(Rect2(-10, -10, 60, 60))
	grid.fill_rect(Rect2(0, 0, 30, 10), WorldBoundaryGrid.WALKABLE)
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	var trees: Array[Vector3] = deco.tree_positions(grid, 2, 3.2, 1)
	assert_gt(trees.size(), 0)
	for p in trees:
		assert_true(p.z >= 11.0, "árbol muy cerca de lo caminable en %s" % p)


func test_el_agua_no_lleva_suelo_ni_arboles_a_su_altura() -> void:
	var deco = Deco.new()
	deco.add_triangles(Deco.Kind.FOREST, _square(0, 0, 30, 0.0))
	deco.add_triangles(Deco.Kind.WATER, _square(0, 0, 15, 0.0))
	for p in deco.tree_positions(null, 0, 3.2, 1):
		assert_false(_inside(p, 0, 0, 15), "árbol en el agua en %s" % p)
	assert_almost_eq(_area(deco.ground_triangles()), 900.0 - 225.0, 12.0)
	assert_eq(deco.water_triangles().size(), 6)


func test_las_praderas_traen_su_bosque_como_guia() -> void:
	# Los ForestFloor de las praderas ahora son AutoForest_: sus árboles los
	# genera la decoración.
	var map: Node = (load("res://assets/maps/crossroads/pradera_norte.glb") as PackedScene).instantiate()
	assert_not_null(map.find_child("AutoForest_PraderaNorte", true, false))
	assert_null(map.find_child("PraderaNorteForestFloor", true, false))
	map.free()
	var playa: Node = (load("res://assets/maps/beach/playa.glb") as PackedScene).instantiate()
	assert_not_null(playa.find_child("AutoWater_PlayaOrilla", true, false), "la orilla de la playa es agua")
	playa.free()


func test_la_biblioteca_de_arboles_trae_moldes() -> void:
	var FB := preload("res://features/world/zones/forest_builder.gd")
	var bosque: Array = FB.library_templates("Bosque")
	assert_eq(bosque.size(), 5, "roble, redondo, pino, pino alto y arbusto")
	for parts in bosque:
		assert_gt((parts as Array).size(), 0)
	assert_eq(FB.library_templates("Playa").size(), 2, "las dos palmeras")


func test_el_agua_de_la_playa_se_arma_con_su_material() -> void:
	var water: Node = ZoneManager._boundary.get_node_or_null("AutoDecoration/AutoWater")
	assert_not_null(water, "la orilla de la playa (AutoWater_PlayaOrilla) es agua")
	assert_true((water as MeshInstance3D).material_override is ShaderMaterial)


func test_los_nombres_de_guia() -> void:
	assert_true(Deco.is_guide("AutoForest_Huecos"))
	assert_true(Deco.is_guide("AutoGround_Margen"))
	assert_true(Deco.is_guide("NoAutoFill_Playa"))
	assert_true(Deco.is_guide("NoAutoTrees_Sendero"))
	assert_true(Deco.is_guide("AutoWater_PlayaOrilla"))
	assert_false(Deco.is_guide("CodoMeadow"))
	assert_false(Deco.is_guide("PlayaHoyoCanyon"))


func test_el_mundo_sale_de_las_guias_de_blender() -> void:
	var boundary: Node = ZoneManager._boundary
	assert_not_null(boundary.get_node_or_null("AutoDecoration/AutoGround"), "suelo armado con las guías")
	assert_null(boundary.get_node_or_null("ForestGround"), "ya no está el plano de antes")
	var trees: Array[Vector3] = boundary.decoration_tree_positions()
	assert_gt(trees.size(), 300)
	var near_gap := false
	var bad := 0
	for p in trees:
		if Vector2(p.x, p.z).distance_to(Vector2(-40, -110)) < 4.0:
			near_gap = true
		# Ni árboles colgando sobre la playa de abajo ni sobre lo caminable.
		if p.x > 195 and p.x < 285 and p.z > -45 and p.z < 55:
			bad += 1
		if boundary.cell_type_at(p) == WorldBoundaryGrid.WALKABLE:
			bad += 1
	assert_true(near_gap, "bosque en el hueco entre los claros del crossroads")
	var gym_center := Vector2(10, 73)
	var near_gym_forest := false
	for p in trees:
		var d := Vector2(p.x, p.z).distance_to(gym_center)
		if d < 32.0:
			bad += 1   # ni en la arena del gym
		if Vector2(p.x, p.z).distance_to(Vector2(50, 73)) < 4.0:
			near_gym_forest = true
	assert_true(near_gym_forest, "el bosque alrededor del gym sale de AutoForest_Gym")
	assert_eq(bad, 0)


func test_las_guias_no_quedan_en_las_zonas() -> void:
	var found := 0
	for zone in ZoneManager.get_loaded_zone_nodes():
		for node in (zone as Node).find_children("*", "", true, false):
			if Deco.is_guide(String(node.name)):
				found += 1
	assert_eq(found, 0)
