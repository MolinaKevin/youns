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


func test_runtime_inyectable_inicia_el_contexto_sin_autoloads() -> void:
	var context := WorldCombatContext.new()
	var biome := BiomeData.new()
	var runtime := WorldCombatRuntime.new(
		context,
		func() -> BiomeData: return biome,
		func() -> PlayerSaveData: return null,
		func() -> bool: return false,
	)
	var youn := YounData.new()

	runtime.begin(Vector3(3, 0, 4), "enemy-runtime", youn)

	assert_true(runtime.is_active())
	assert_eq(context.return_position, Vector3(3, 0, 4))
	assert_eq(context.world_enemy_id, "enemy-runtime")
	assert_eq(context.wild_youn_data, youn)
	assert_eq(context.biome, biome)
