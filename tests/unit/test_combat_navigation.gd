extends GutTest


func test_click_fuera_de_rango_planifica_hasta_la_casilla_alcanzable_mas_cercana() -> void:
	var terrain := CombatTerrain.new()
	terrain.configure(20.0, 20.0)
	var navigation := CombatNavigation.new()
	navigation.configure(terrain, 20.0, 20.0)
	navigation.begin_move(Vector2(2.0, 2.0), 2.0, 0, 0.2, Vector2(15.0, 15.0), 0.2)

	var error := navigation.plan_move(Vector2(10.0, 2.0), 0, 0.2, Vector2(15.0, 15.0), 0.2)

	assert_eq(error, "")
	assert_false(navigation.last_path.is_empty())
	assert_eq(navigation.last_path[-1], CombatGrid.to_world(Vector2i(49, 25)))
	assert_almost_eq(navigation.last_path_cost, 1.92, 0.0001)
