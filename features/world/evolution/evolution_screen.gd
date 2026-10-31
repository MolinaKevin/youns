extends CanvasLayer

## Pantalla que aparece al terminar una evolución: muestra lo que pasó y deja
## elegir lo que depende del jugador. Cuatro menús:
##   - Suma de estadísticas: lo que sumó (o restó) cada stat.
##   - Cambio de color: elegir qué mitades del mazo pasan a cada inteligencia
##     que ofrece la evolución (YounData.color_changes).
##   - Cartas agregadas: la carta característica que entró al mazo.
##   - Acciones agregadas: elegir a qué mitad va cada línea que ofrece la
##     evolución (YounData.granted_lines), hasta DeckRules.MAX_LINES_PER_HALF.
## Los cambios se hacen sobre el mazo de la partida. "Terminar" se habilita
## recién cuando se usaron todos los colores y se pusieron todas las acciones
## (una acción no cuenta si ya no queda ninguna mitad con lugar). Se guarda al
## dormir o en una estación de guardado, como todo.

signal finished

const Intelligences := preload("res://data/youns/intelligences.gd")
const CardViewScript := preload("res://features/cards/presentation/card_view.gd")
const EvolutionDraftScript := preload("res://features/world/evolution/evolution_draft.gd")
const SectionRenderer := preload("res://features/world/evolution/evolution_section_renderer.gd")
const CARD_SCENE := preload("res://features/cards/presentation/card_view.tscn")
const CARD_SIZE := Vector2(195, 293)
const GRID_CARD_SCALE := 0.6
const PANEL_BG := Color(0.04, 0.09, 0.14, 0.97)
const BORDER := Color(0.35, 0.85, 1.0)
const LOSS := Color(1.0, 0.45, 0.4)

enum Section { STATS, COLORS, CARDS, ACTIONS }

var _result: Dictionary
var _to: YounData
var _draft: EvolutionDraft

var _section_buttons := {}
var _content: VBoxContainer
var _hint: Label
var _finish_button: Button
var _pending_label: Label

## Vista de cada carta en la grilla del mazo, para redibujarla al cambiarla.
var _card_views := {}
## La lógica de reparto no depende de CardView. Las pruebas y herramientas que
## sólo ejercitan esa lógica pueden evitar instanciar la presentación pesada.
var render_deck_views := true
## Ejecuta sólo el estado de la evolución, sin construir controles. Mantiene la
## lógica verificable en tests de unidad y deja la presentación como detalle.
var logic_only := false

func setup(result: Dictionary) -> void:
	_result = result
	_to = result.get("to")
	_draft = EvolutionDraftScript.new(_to, DeckRules.cards(PlayerSessionAccess.save()))

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if logic_only:
		return
	_build()
	_show_section(Section.STATS)
	_refresh_pending()

# ── API de interacción ──────────────────────────────────────────────────────

## Muestra una de las cuatro secciones de la pantalla.
func show_section(section: Section) -> void:
	if logic_only:
		_draft.show_section(section)
		return
	_show_section(section)

## Elige el color que se aplicará al pulsar una mitad de carta.
func select_color(id: String) -> void:
	if _draft.select_color(id):
		_state_changed()

## Elige una línea concedida para agregar al pulsar una mitad de carta.
func select_line(index: int) -> void:
	if _draft.select_line(index):
		_state_changed()

## Aplica la selección actual a la mitad indicada de una carta del mazo.
func apply_to_half(card: CardData, is_top: bool) -> void:
	_on_half_pressed(card, is_top)

## Deshace el último cambio de color.
func undo_color() -> void:
	_undo("color")

## Deshace la última línea agregada.
func undo_line() -> void:
	_undo("line")

## Cartas sobre las que se pueden aplicar los cambios de evolución.
func deck_cards() -> Array[CardData]:
	return _draft.deck

## Indica si el botón Terminar está habilitado para el jugador.
func is_finish_enabled() -> bool:
	return _draft.can_finish()

## Intenta terminar la evolución. Devuelve si la pantalla se pudo cerrar.
func finish() -> bool:
	if not _draft.can_finish():
		return false
	finished.emit()
	queue_free()
	return true

# ── Armado ───────────────────────────────────────────────────────────────────

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.text = LocalizationState.t("evolution.title", [_youn_name(_result.get("from")), _youn_name(_to)])
	column.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(250, 0)
	menu.add_theme_constant_override("separation", 8)
	body.add_child(menu)
	var group := ButtonGroup.new()
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.1, 0.25, 0.35)
	selected_style.border_color = BORDER
	selected_style.set_border_width_all(2)
	selected_style.set_corner_radius_all(6)
	for section in [Section.STATS, Section.COLORS, Section.CARDS, Section.ACTIONS]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_stylebox_override("pressed", selected_style)
		b.text = LocalizationState.t(_section_key(section))
		b.pressed.connect(show_section.bind(section))
		menu.add_child(b)
		_section_buttons[section] = b

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_hint)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	right.add_child(_content)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_pending_label = Label.new()
	_pending_label.add_theme_color_override("font_color", LOSS)
	footer.add_child(_pending_label)
	_finish_button = Button.new()
	_finish_button.text = LocalizationState.t("evolution.finish")
	_finish_button.custom_minimum_size = Vector2(200, 48)
	_finish_button.pressed.connect(finish)
	footer.add_child(_finish_button)

func _section_key(section: Section) -> String:
	match section:
		Section.STATS: return "evolution.section.stats"
		Section.COLORS: return "evolution.section.colors"
		Section.CARDS: return "evolution.section.cards"
		_: return "evolution.section.actions"

func _youn_name(data: YounData) -> String:
	return data.youn_name if data != null else "?"

func _show_section(section: Section) -> void:
	_draft.show_section(section)
	for s in _section_buttons:
		_section_buttons[s].set_pressed_no_signal(s == section)
	_card_views.clear()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match section:
		Section.STATS: _build_stats()
		Section.COLORS: _build_colors()
		Section.CARDS: _build_cards()
		Section.ACTIONS: _build_actions()

# ── Suma de estadísticas ────────────────────────────────────────────────────

func _build_stats() -> void:
	var changes: Dictionary = _result.get("stat_changes", {})
	_hint.text = ""
	SectionRenderer.build_stats(_content, changes)

# ── Cartas agregadas ────────────────────────────────────────────────────────

func _build_cards() -> void:
	_hint.text = ""
	var card: CardData = _result.get("added_card")
	SectionRenderer.build_card(_content, card)

# ── Cambio de color ─────────────────────────────────────────────────────────

func _build_colors() -> void:
	if _draft.remaining_colors.is_empty():
		_hint.text = ""
		_content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	_hint.text = LocalizationState.t("evolution.colors_hint")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_content.add_child(bar)
	for id in _draft.remaining_colors:
		var chip := Button.new()
		chip.toggle_mode = true
		chip.custom_minimum_size = Vector2(0, 40)
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = Intelligences.half_color(id)
		chip_style.border_color = Intelligences.color(id)
		chip_style.set_border_width_all(2)
		chip_style.set_corner_radius_all(6)
		chip_style.set_content_margin_all(8)
		var pressed_style := chip_style.duplicate()
		pressed_style.set_border_width_all(4)
		pressed_style.border_color = Color.WHITE
		chip.add_theme_stylebox_override("normal", chip_style)
		chip.add_theme_stylebox_override("hover", chip_style)
		chip.add_theme_stylebox_override("pressed", pressed_style)
		chip.add_theme_stylebox_override("disabled", chip_style)
		chip.text = "%s  ×%d" % [Intelligences.display_name(id), _draft.remaining_colors[id]]
		chip.disabled = _draft.remaining_colors[id] <= 0
		chip.button_pressed = id == _draft.selected_color
		chip.pressed.connect(func() -> void:
			if chip.button_pressed:
				select_color(id)
			else:
				_draft.clear_color_selection()
				_state_changed())
		bar.add_child(chip)
	bar.add_child(_undo_button("color"))
	_content.add_child(_deck_grid())

## Redibuja la sección actual (colores o acciones) sin perder lo elegido.
func _rebuild_keeping_selection() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_card_views.clear()
	if _draft.section == Section.COLORS:
		_build_colors()
	else:
		_build_actions()
	_refresh_pending()


## Actualiza la vista sólo cuando existe; el estado se modifica antes de llegar
## aquí y por eso el mismo flujo puede usarse sin UI.
func _state_changed() -> void:
	if not logic_only:
		_rebuild_keeping_selection()

# ── Acciones agregadas ──────────────────────────────────────────────────────

func _build_actions() -> void:
	if _to == null or _to.granted_lines.is_empty():
		_hint.text = ""
		_content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	_hint.text = LocalizationState.t("evolution.actions_hint", [DeckRules.MAX_LINES_PER_HALF])
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_content.add_child(bar)
	var stats := CardScaling.player_stats()
	for i in _to.granted_lines.size():
		var line: CardActionLine = _to.granted_lines[i]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 44)
		b.disabled = _draft.used_lines[i]
		b.button_pressed = i == _draft.selected_line
		b.tooltip_text = line.description
		var row: HBoxContainer = CardViewScript.line_row(line.resolved(stats), "")
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _draft.used_lines[i]:
			row.modulate.a = 0.35
		b.add_child(row)
		b.pressed.connect(func() -> void:
			if b.button_pressed:
				select_line(i)
			else:
				_draft.clear_line_selection()
				_state_changed())
		bar.add_child(b)
	bar.add_child(_undo_button("line"))
	_content.add_child(_deck_grid())

# ── Mazo ────────────────────────────────────────────────────────────────────

func _deck_grid() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Se acomoda al ancho: pasa a la fila siguiente cuando no entran más cartas.
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for card in _draft.deck:
		var holder := Control.new()
		holder.custom_minimum_size = CARD_SIZE * GRID_CARD_SCALE
		grid.add_child(holder)
		if not render_deck_views:
			continue
		var view = CARD_SCENE.instantiate()
		view.hover_enabled = false
		view.scale = Vector2.ONE * GRID_CARD_SCALE
		holder.add_child(view)
		view.setup(card)
		view.halves_selectable = true
		view.half_pressed.connect(apply_to_half)
		_card_views[card] = view
	return scroll

func _on_half_pressed(card: CardData, is_top: bool) -> void:
	var result := _draft.apply_to_half(card, is_top)
	if result == "half_full" and not logic_only:
		_hint.text = LocalizationState.t("evolution.half_full", [DeckRules.MAX_LINES_PER_HALF])
		return
	if result == "":
		_state_changed()

# ── Deshacer ────────────────────────────────────────────────────────────────

func _undo_button(type: String) -> Button:
	var b := Button.new()
	b.text = LocalizationState.t("evolution.undo")
	b.custom_minimum_size = Vector2(0, 40)
	b.disabled = not _draft.history.any(func(op: Dictionary) -> bool: return op["type"] == type)
	b.pressed.connect(_undo.bind(type))
	return b

## Deshace el último cambio de ese tipo (color o línea).
func _undo(type: String) -> void:
	if _draft.undo(type):
		_state_changed()

# ── Pendientes ──────────────────────────────────────────────────────────────

## Colores que quedan por poner.
func pending_colors() -> int:
	return _draft.pending_colors()

## Acciones que quedan por poner. Si ya no queda ninguna mitad con lugar, no
## cuentan (si no, no se podría terminar nunca).
func pending_lines() -> int:
	return _draft.pending_lines()

func can_finish() -> bool:
	return _draft.can_finish()

## Marca en el menú lo que falta y habilita "Terminar" cuando no falta nada.
func _refresh_pending() -> void:
	var colors := pending_colors()
	var lines := pending_lines()
	for section in _section_buttons:
		var text := LocalizationState.t(_section_key(section))
		var pending: int = colors if section == Section.COLORS else (lines if section == Section.ACTIONS else 0)
		_section_buttons[section].text = text + ("  (%d)" % pending if pending > 0 else "")
	var missing: Array[String] = []
	if colors > 0:
		missing.append(LocalizationState.t("evolution.pending_colors", [colors]))
	if lines > 0:
		missing.append(LocalizationState.t("evolution.pending_actions", [lines]))
	_pending_label.text = "" if missing.is_empty() else LocalizationState.t("evolution.pending", [", ".join(missing)])
	_finish_button.disabled = not missing.is_empty()

# ── Fin ─────────────────────────────────────────────────────────────────────

func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label
