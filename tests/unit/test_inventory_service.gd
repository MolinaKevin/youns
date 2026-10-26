extends GutTest

const InventoryService := preload("res://shared/inventory_service.gd")


func _entry(id: String, count: int) -> Dictionary:
	return {"id": id, "name": id, "count": count}


func test_agregar_respeta_el_limite_de_pila_y_devuelve_el_resto() -> void:
	var items: Array[Dictionary] = [_entry("potion", 18)]

	var result := InventoryService.add_entry(items, _entry("potion", 5), 20)

	assert_eq(items[0]["count"], 20)
	assert_eq(result, {"added": 2, "remaining": 3})


func test_agregar_respeta_la_capacidad_del_inventario() -> void:
	var items: Array[Dictionary] = [_entry("potion", 1)]

	var result := InventoryService.add_entry(items, _entry("herb", 2), 1)

	assert_eq(items.size(), 1)
	assert_eq(result, {"added": 0, "remaining": 2})


func test_consumir_resta_o_elimina_la_entrada() -> void:
	var items: Array[Dictionary] = [_entry("potion", 2), _entry("herb", 1)]

	assert_eq(InventoryService.consume_at(items, 0), 1)
	assert_eq(items[0]["count"], 1)
	assert_eq(InventoryService.consume_at(items, 1), 1)
	assert_eq(items.size(), 1)
