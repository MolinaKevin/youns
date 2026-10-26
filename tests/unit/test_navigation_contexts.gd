extends GutTest



func test_entrada_al_mundo_se_consume_una_sola_vez() -> void:
	var context := WorldEntryContext.new()
	context.request_restore("gym", Vector3(1, 2, 3), "res://interior.tscn")
	var entry := context.take()
	assert_true(entry.pending)
	assert_eq(entry.zone_id, "gym")
	assert_eq(entry.position, Vector3(1, 2, 3))
	assert_false(context.pending)


func test_retorno_de_ui_se_limpia_al_consumirlo() -> void:
	var context := UiReturnContext.new()
	context.set_return("res://world.tscn")
	assert_eq(context.take_scene_path(), "res://world.tscn")
	assert_false(context.has_return())
