extends GutTest

func test_carga_solo_el_tipo_pedido_y_en_orden() -> void:
	var resources := ResourceCatalogLoader.resources("res://data/items", ItemData)
	assert_gt(resources.size(), 0)
	var paths := PackedStringArray()
	for resource in resources:
		assert_is(resource, ItemData)
		paths.append(resource.resource_path)
	var sorted := paths.duplicate()
	sorted.sort()
	assert_eq(paths, sorted)

func test_directorio_inexistente_no_falla() -> void:
	assert_eq(ResourceCatalogLoader.resources("res://data/no-existe", ItemData), [])
