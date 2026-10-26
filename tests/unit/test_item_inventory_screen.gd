extends GutTest

const InventoryScene := preload("res://features/items/ui/item_inventory_screen.tscn")

var _save_before: PlayerSaveData


func before_each() -> void:
	_save_before = GameState.player_save
	GameState.player_save = PlayerSaveData.new()


func after_each() -> void:
	GameState.player_save = _save_before


func test_usar_un_item_sin_recurso_no_lo_consumo() -> void:
	GameState.player_save.inventory_items = [{
		"id": "missing",
		"name": "Missing",
		"data_path": "res://data/items/no_existe.tres",
		"count": 2,
	}]
	var screen := InventoryScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.use_selected_item())
	assert_eq(GameState.player_save.inventory_items.size(), 1)
	assert_eq(GameState.player_save.inventory_items[0]["count"], 2)
