extends GutTest


func test_catalogos_y_grafo_de_zonas_pasan_la_validacion_de_runtime() -> void:
	assert_eq(GameDataValidator.card_errors(CardCatalog.load_all()), PackedStringArray())
	assert_eq(GameDataValidator.item_errors(), PackedStringArray())
	assert_eq(GameDataValidator.youn_errors(), PackedStringArray())
	assert_eq(GameDataValidator.recipe_errors(LaboratoryRecipeCatalog.load_all("res://data/lab_recipes/")), PackedStringArray())
	assert_eq(GameDataValidator.zone_graph_errors(ZoneManager.catalog), PackedStringArray())
