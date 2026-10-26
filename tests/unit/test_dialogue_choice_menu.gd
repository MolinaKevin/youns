extends GutTest

const DialogueChoiceMenuScript := preload("res://features/dialogue/dialogue_choice_menu.gd")

class ChoiceHost extends Node:
	signal choice_made(index: int)

	var opened := 0
	var closed := 0
	var added_buttons: Array[Button] = []

	func open_choice_menu() -> void:
		opened += 1

	func close_choice_menu() -> void:
		closed += 1

	func add_choice_button(button: Button) -> void:
		added_buttons.append(button)

	func resolve_choice(index: int) -> void:
		choice_made.emit(index)


var _result := -99


func _wait_for_choice(menu: DialogueChoiceMenu, options: Array[String]) -> void:
	_result = await menu.ask(options)


func _pressed_action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _host() -> ChoiceHost:
	var host := ChoiceHost.new()
	add_child_autofree(host)
	return host


func test_abrir_y_elegir_usa_la_api_del_host() -> void:
	var host := _host()
	var menu := DialogueChoiceMenuScript.new(host)
	_wait_for_choice(menu, ["Primera", "Segunda"])

	assert_eq(host.opened, 1)
	assert_true(menu.active)
	assert_eq(host.added_buttons.size(), 2)
	assert_eq(host.added_buttons[0].text, "▶  Primera")

	menu.resolve(1)
	await get_tree().process_frame
	assert_eq(_result, 1)
	assert_eq(host.closed, 1)
	assert_false(menu.active)
	assert_eq(menu.buttons.size(), 0)


func test_navegacion_y_cancelacion_eligen_menos_uno() -> void:
	var host := _host()
	var menu := DialogueChoiceMenuScript.new(host)
	_wait_for_choice(menu, ["Primera", "Segunda"])

	assert_true(menu.handle_input(_pressed_action("ui_down")))
	assert_eq(menu.index, 1)
	assert_eq(host.added_buttons[1].text, "▶  Segunda")
	assert_true(menu.handle_input(_pressed_action("ui_cancel")))
	await get_tree().process_frame
	assert_eq(_result, -1)
	assert_eq(host.closed, 1)


func test_lista_vacia_no_abre_el_menu() -> void:
	var host := _host()
	var menu := DialogueChoiceMenuScript.new(host)

	_wait_for_choice(menu, [])
	await get_tree().process_frame
	assert_eq(_result, -1)
	assert_eq(host.opened, 0)
