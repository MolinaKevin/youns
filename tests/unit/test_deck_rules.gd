extends GutTest

# Mazo propio de la partida (DeckRules) y lo que le hace la evolución.

const DILUVIO := "res://data/cards/diluvio.tres"


func test_clone_no_comparte_mitades_ni_lineas_con_la_original() -> void:
	var original: CardData = load(DILUVIO)
	var copy := original.clone()
	assert_ne(copy.top, original.top)
	assert_ne(copy.top.lines[0], original.top.lines[0])
	copy.top.lines[0].damage = 999
	assert_ne(original.top.lines[0].damage, 999)


func test_ensure_deck_arma_copias_desde_los_ids() -> void:
	var save := PlayerSaveData.new()
	save.equipped_deck_ids = ["strike", "strike", "block"]
	DeckRules.ensure_deck(save)
	assert_eq(save.deck.size(), 3)
	assert_ne(save.deck[0], CardDatabase.get_card("strike"))
	assert_ne(save.deck[0], save.deck[1])


func test_ensure_deck_no_pisa_un_mazo_existente() -> void:
	var save := PlayerSaveData.new()
	save.equipped_deck_ids = ["strike"]
	save.deck = [CardDatabase.get_card("block").clone()]
	DeckRules.ensure_deck(save)
	assert_eq(save.deck.size(), 1)
	assert_eq(save.deck[0].id, "block")


func test_recolor_cambia_color_e_inteligencia_de_la_copia_sola() -> void:
	var original: CardData = load(DILUVIO)
	var original_intelligence := original.top.intelligence
	var copy := original.clone()
	DeckRules.recolor(copy.top, "musical")
	assert_eq(copy.top.intelligence, "musical")
	assert_ne(copy.top.color, original.top.color)
	assert_eq(original.top.intelligence, original_intelligence)


func test_add_line_agrega_una_copia_al_final() -> void:
	var copy: CardData = (load(DILUVIO) as CardData).clone()
	var line := CardActionLine.new()
	line.card_type = "block"
	assert_true(DeckRules.add_line(copy.bottom, line))
	assert_eq(copy.bottom.lines.size(), 2)
	assert_eq(copy.bottom.lines[1].card_type, "block")
	assert_ne(copy.bottom.lines[1], line)


func test_add_line_no_pasa_el_maximo_de_5() -> void:
	var copy: CardData = (load(DILUVIO) as CardData).clone()
	var line := CardActionLine.new()
	for i in 10:
		DeckRules.add_line(copy.bottom, line)
	assert_eq(copy.bottom.lines.size(), DeckRules.MAX_LINES_PER_HALF)
	assert_false(DeckRules.can_add_line(copy.bottom))


func test_tope_de_lineas_por_etapa() -> void:
	assert_eq(DeckRules.line_cap("bebe"), 1)
	assert_eq(DeckRules.line_cap("nino"), 2)
	assert_eq(DeckRules.line_cap("adolescente"), 3)
	assert_eq(DeckRules.line_cap("campeon"), 4)
	assert_eq(DeckRules.line_cap("ultimate"), 5)
