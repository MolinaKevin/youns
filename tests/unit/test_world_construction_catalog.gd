extends GutTest

const WorldConstructionCatalogScript := preload("res://data/world/world_construction_catalog.gd")


func test_catalogo_carga_el_puente_del_rio_para_el_hub() -> void:
	var catalog := WorldConstructionCatalogScript.new()
	var constructions := catalog.for_zone("hub")

	assert_eq(constructions.size(), 1)
	assert_eq(constructions[0].id, "river_bridge")
	assert_eq(constructions[0].unlock_recipe_id, "construccion_de_puente")
