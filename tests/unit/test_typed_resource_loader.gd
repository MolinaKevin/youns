extends GutTest

const Loader := preload("res://shared/typed_resource_loader.gd")


func test_carga_recursos_del_tipo_pedido() -> void:
	assert_not_null(Loader.youn("res://data/youns/newen.tres"))
	assert_not_null(Loader.item("res://data/items/hierba_curativa.tres"))
	assert_not_null(Loader.lab_recipe("res://data/lab_recipes/producir_datos.tres"))


func test_devuelve_null_para_rutas_inexistentes_o_tipo_incorrecto() -> void:
	assert_null(Loader.youn("res://data/items/hierba_curativa.tres"))
	assert_null(Loader.item("res://data/items/no_existe.tres"))
	assert_null(Loader.lab_recipe("res://data/items/hierba_curativa.tres"))
