extends GutTest

const ZoneCatalog := preload("res://data/zones/zone_catalog.gd")


func test_catalogo_valida_escenas_y_conexiones() -> void:
	var catalog := ZoneCatalog.new()
	assert_eq(catalog.validate().size(), 0)
	assert_true(catalog.has("hub"))
	assert_eq(catalog.definition("beach").offset, Vector3(225, 0, 0))


func test_las_definiciones_exponen_las_conexiones() -> void:
	var bend := ZoneCatalog.new().definition("bend")
	assert_true("beach" in bend.connections)
	assert_true(bend.resource_path.ends_with("data/zones/definitions/bend.tres"))


func test_los_ids_duplicados_de_un_fixture_se_reportan() -> void:
	var first := ZoneDefinition.new()
	first.id = "duplicada"
	first.scene_path = "res://tests/fixtures/zones/fixture_zone.tscn"
	var second := ZoneDefinition.new()
	second.id = "duplicada"
	second.scene_path = first.scene_path
	var definitions: Array[ZoneDefinition] = [first, second]
	var errors := ZoneCatalog.from_definitions(definitions).validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "duplicado")
