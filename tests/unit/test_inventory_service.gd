extends GutTest

const InventoryServiceScript := preload("res://shared/inventory_service.gd")


func _entry(id: String, count: int) -> Dictionary:
	return {"id": id, "name": id, "count": count}


func test_agregar_respeta_el_limite_de_pila_y_devuelve_el_resto() -> void:
	var items: Array[Dictionary] = [_entry("potion", 18)]

	var result := InventoryServiceScript.add_entry(items, _entry("potion", 5), 20)

	assert_eq(items[0]["count"], 20)
	assert_eq(result, {"added": 2, "remaining": 3})


func test_agregar_respeta_la_capacidad_del_inventario() -> void:
	var items: Array[Dictionary] = [_entry("potion", 1)]

	var result := InventoryServiceScript.add_entry(items, _entry("herb", 2), 1)

	assert_eq(items.size(), 1)
	assert_eq(result, {"added": 0, "remaining": 2})


func test_consumir_resta_o_elimina_la_entrada() -> void:
	var items: Array[Dictionary] = [_entry("potion", 2), _entry("herb", 1)]

	assert_eq(InventoryServiceScript.consume_at(items, 0), 1)
	assert_eq(items[0]["count"], 1)
	assert_eq(InventoryServiceScript.consume_at(items, 1), 1)
	assert_eq(items.size(), 1)


func test_sanear_une_duplicados_limita_pilas_y_rehace_los_datos() -> void:
	var items: Array[Dictionary] = [
		{"id": "viejo", "name": "Viejo", "data_path": "res://data/items/hierba_curativa.tres", "count": 18},
		{"id": "otro", "name": "Otro", "data_path": "res://data/items/hierba_curativa.tres", "count": 7},
		{"id": "invalido", "data_path": "res://data/items/no_existe.tres", "count": 2},
	]

	var sanitized := InventoryServiceScript.sanitize_entries(items, 2)

	assert_eq(sanitized.size(), 2)
	assert_eq(sanitized[0]["id"], "hierba_curativa")
	assert_eq(sanitized[0]["count"], 20)
	assert_eq(sanitized[1]["count"], 5)
