extends GutTest


func _make_item(p_id: String, p_name: String) -> ItemData:
	var d := ItemData.new()
	d.id = p_id
	d.name = p_name
	return d


# ── to_inventory_entry ────────────────────────────────────────────────────────

func test_to_inventory_entry_contiene_id_y_nombre() -> void:
	var entry := _make_item("potion", "Poción").to_inventory_entry()
	assert_eq(entry.get("id"), "potion")
	assert_eq(entry.get("name"), "Poción")


func test_to_inventory_entry_count_por_defecto_es_1() -> void:
	var entry := _make_item("potion", "Poción").to_inventory_entry()
	assert_eq(entry.get("count"), 1)


func test_to_inventory_entry_count_personalizado() -> void:
	var entry := _make_item("potion", "Poción").to_inventory_entry(5)
	assert_eq(entry.get("count"), 5)


func test_to_inventory_entry_icon_vacio_sin_textura() -> void:
	var entry := _make_item("potion", "Poción").to_inventory_entry()
	assert_eq(entry.get("icon"), "")
