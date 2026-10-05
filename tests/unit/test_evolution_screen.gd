extends GutTest

# La pantalla de evolución no deja terminar hasta usar todos los colores y
# poner todas las acciones.

const EvolutionScreen := preload("res://features/world/evolution/evolution_screen.gd")

var _save_before: PlayerSaveData


func before_each() -> void:
	_save_before = GameState.player_save
	var save := PlayerSaveData.new()
	save.equipped_deck_ids = ["strike", "block"]
	GameState.player_save = save


func after_each() -> void:
	GameState.player_save = _save_before


func _line() -> CardActionLine:
	var line := CardActionLine.new()
	line.description = "test"
	return line


func _screen(colors: Dictionary, lines: int) -> CanvasLayer:
	var to := YounData.new()
	to.youn_name = "Test"
	for id in colors:
		to.color_changes[id] = colors[id]
	for i in lines:
		to.granted_lines.append(_line())
	var screen: CanvasLayer = EvolutionScreen.new()
	screen.setup({"to": to, "stat_changes": {}})
	add_child_autofree(screen)
	return screen


func test_sin_nada_para_poner_se_puede_terminar() -> void:
	var screen := _screen({}, 0)
	assert_true(screen.can_finish())
	assert_false(screen._finish_button.disabled)


func test_con_colores_y_acciones_pendientes_no_se_puede_terminar() -> void:
	var screen := _screen({"logica": 1}, 1)
	assert_eq(screen.pending_colors(), 1)
	assert_eq(screen.pending_lines(), 1)
	assert_false(screen.can_finish())
	assert_true(screen._finish_button.disabled)


func test_terminar_no_cierra_con_pendientes() -> void:
	var screen := _screen({"logica": 1}, 0)
	watch_signals(screen)
	screen._on_finish()
	assert_signal_not_emitted(screen, "finished")


func test_al_poner_todo_se_habilita_terminar() -> void:
	var screen := _screen({"logica": 1}, 1)
	var card: CardData = screen._deck[0]
	screen._show_section(screen.Section.COLORS)
	screen._selected_color = "logica"
	screen._on_half_pressed(card, true)
	assert_true(screen._finish_button.disabled, "falta la acción")
	screen._show_section(screen.Section.ACTIONS)
	screen._selected_line = 0
	screen._on_half_pressed(card, true)
	assert_true(screen.can_finish())
	assert_false(screen._finish_button.disabled)


func test_deshacer_vuelve_a_bloquear() -> void:
	var screen := _screen({"logica": 1}, 0)
	screen._show_section(screen.Section.COLORS)
	screen._selected_color = "logica"
	screen._on_half_pressed(screen._deck[0], true)
	assert_true(screen.can_finish())
	screen._undo("color")
	assert_false(screen.can_finish())
	assert_true(screen._finish_button.disabled)


func test_si_no_hay_lugar_las_acciones_no_traban() -> void:
	var screen := _screen({}, 1)
	for card in screen._deck:
		for action in [card.top, card.bottom]:
			if action == null:
				continue
			while DeckRules.can_add_line(action):
				DeckRules.add_line(action, _line())
	assert_eq(screen.pending_lines(), 0)
	assert_true(screen.can_finish())
