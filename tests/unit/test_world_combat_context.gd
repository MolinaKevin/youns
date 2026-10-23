extends GutTest



func test_begin_conserva_el_retorno_hasta_limpiar() -> void:
	var context := WorldCombatContext.new()
	var pos := Vector3(2, 0, 3)
	context.begin(pos, "enemy-7", null, null)
	assert_true(context.active)
	assert_eq(context.return_position, pos)
	assert_eq(context.world_enemy_id, "enemy-7")
	context.clear()
	assert_false(context.active)
	assert_eq(context.world_enemy_id, "")


func test_tomar_youn_no_cierra_la_transicion() -> void:
	var context := WorldCombatContext.new()
	var youn := YounData.new()
	context.begin(Vector3.ZERO, "enemy", youn, null)
	assert_eq(context.take_wild_youn_data(), youn)
	assert_null(context.wild_youn_data)
	assert_true(context.active)
