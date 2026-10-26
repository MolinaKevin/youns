extends GutTest

const MainMenuScene := preload("res://features/menus/main_menu/main_menu.tscn")

var _save_before: PlayerSaveData


func before_each() -> void:
	_save_before = GameState.player_save
	GameState.player_save = PlayerSaveData.new()


func after_each() -> void:
	GameState.player_save = _save_before


func _menu() -> Control:
	var menu := MainMenuScene.instantiate() as Control
	add_child_autofree(menu)
	return menu


func test_el_item_bloqueado_no_esta_en_la_lista_visible() -> void:
	var menu := _menu()
	assert_eq(menu._items.size(), 6)
	assert_eq(menu._visible_menu_items.size(), 6)
	for data: Dictionary in menu._visible_menu_items:
		assert_ne(data.get("name_key"), "main_menu.reincarnated_cards")


func test_el_desbloqueo_agrega_el_item_visible_correcto() -> void:
	GameState.player_save.reincarnated_cards_unlocked = true
	var menu := _menu()
	assert_eq(menu._items.size(), 7)
	assert_eq(menu._visible_menu_items.size(), 7)
	var last: Dictionary = menu._visible_menu_items.back()
	assert_eq(last.get("name_key"), "main_menu.reincarnated_cards")
	assert_eq(last.get("scene"), "res://features/cards/ui/reincarnated_cards_screen.tscn")


func test_dormir_se_identifica_por_accion_y_no_por_indice() -> void:
	var menu := _menu()
	var sleep_index := -1
	for index in menu._visible_menu_items.size():
		if menu._visible_menu_items[index].get("action", "") == "sleep":
			sleep_index = index
			break
	assert_ne(sleep_index, -1)
	assert_eq(menu._visible_menu_items[sleep_index].get("name_key"), "main_menu.sleep")
