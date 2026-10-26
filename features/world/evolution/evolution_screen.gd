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
const CARD_SCENE := preload("res://features/cards/presentation/card_view.tscn")
const CARD_SIZE := Vector2(195, 293)
const GRID_CARD_SCALE := 0.6
const PANEL_BG := Color(0.04, 0.09, 0.14, 0.97)
const BORDER := Color(0.35, 0.85, 1.0)
const GAIN := Color(0.5, 1.0, 0.55)
const LOSS := Color(1.0, 0.45, 0.4)

enum Section { STATS, COLORS, CARDS, ACTIONS }

var _result: Dictionary
var _to: YounData
var _deck: Array[CardData] = []

var _section := Section.STATS
var _section_buttons := {}
var _content: VBoxContainer
var _hint: Label
var _finish_button: Button
var _pending_label: Label

## Colores que quedan por usar: {"musical": 1, ...}
var _remaining_colors := {}
var _selected_color := ""
## Líneas que ya se pusieron (por índice en granted_lines).
var _used_lines: Array[bool] = []
var _selected_line := -1
## Cambios hechos, para deshacer: {"type": "color"|"line", "card", "action", ...}
var _history: Array[Dictionary] = []
## Vista de cada carta en la grilla del mazo, para redibujarla al cambiarla.
var _card_views := {}

func setup(result: Dictionary) -> void:
	_result = result
	_to = result.get("to")
	_deck = DeckRules.cards(GameState.player_save)
	if _to != null:
		for id in _to.color_changes:
			_remaining_colors[id] = _to.color_changes[id]
		_used_lines.resize(_to.granted_lines.size())
		_used_lines.fill(false)

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	_show_section(Section.STATS)
	_refresh_pending()

# ── API de interacción ──────────────────────────────────────────────────────

## Muestra una de las cuatro secciones de la pantalla.
func show_section(section: Section) -> void:
	_show_section(section)

## Elige el color que se aplicará al pulsar una mitad de carta.
func select_color(id: String) -> void:
	if _section != Section.COLORS or _remaining_colors.get(id, 0) <= 0:
		return
	_selected_color = id
	_rebuild_keeping_selection()

## Elige una línea concedida para agregar al pulsar una mitad de carta.
func select_line(index: int) -> void:
	if _section != Section.ACTIONS or index < 0 or index >= _used_lines.size() or _used_lines[index]:
		return
	_selected_line = index
	_rebuild_keeping_selection()

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
	return _deck

## Indica si el botón Terminar está habilitado para el jugador.
func is_finish_enabled() -> bool:
	return can_finish()

## Intenta terminar la evolución. Devuelve si la pantalla se pudo cerrar.
func finish() -> bool:
	if not can_finish():
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
	_section = section
	for s in _section_buttons:
		_section_buttons[s].set_pressed_no_signal(s == section)
	_selected_color = ""
	_selected_line = -1
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
	if changes.is_empty():
		_content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for key in YounStats.KEYS:
		if not changes.has(key):
			continue
		var delta: int = changes[key]
		var name_label := Label.new()
		name_label.text = LocalizationState.t("youn_stat." + key)
		name_label.add_theme_font_size_override("font_size", 20)
		grid.add_child(name_label)
		var value := Label.new()
		value.text = ("+%d" if delta > 0 else "%d") % delta
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", GAIN if delta > 0 else LOSS)
		grid.add_child(value)

# ── Cartas agregadas ────────────────────────────────────────────────────────

func _build_cards() -> void:
	_hint.text = ""
	var card: CardData = _result.get("added_card")
	if card == null:
		_content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(center)
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE
	center.add_child(holder)
	var view = CARD_SCENE.instantiate()
	view.hover_enabled = false
	holder.add_child(view)
	view.setup(card)

# ── Cambio de color ─────────────────────────────────────────────────────────

func _build_colors() -> void:
	if _remaining_colors.is_empty():
		_hint.text = ""
		_content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	_hint.text = LocalizationState.t("evolution.colors_hint")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_content.add_child(bar)
	for id in _remaining_colors:
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
		chip.text = "%s  ×%d" % [Intelligences.display_name(id), _remaining_colors[id]]
		chip.disabled = _remaining_colors[id] <= 0
		chip.button_pressed = id == _selected_color
		chip.pressed.connect(func() -> void:
			if chip.button_pressed:
				select_color(id)
			else:
				_selected_color = ""
				_rebuild_keeping_selection())
		bar.add_child(chip)
	bar.add_child(_undo_button("color"))
	_content.add_child(_deck_grid())

## Redibuja la sección actual (colores o acciones) sin perder lo elegido.
func _rebuild_keeping_selection() -> void:
	var keep_color := _selected_color
	var keep_line := _selected_line
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_card_views.clear()
	_selected_color = keep_color
	_selected_line = keep_line
	if _section == Section.COLORS:
		_build_colors()
	else:
		_build_actions()
	_refresh_pending()

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
		b.disabled = _used_lines[i]
		b.button_pressed = i == _selected_line
		b.tooltip_text = line.description
		var row: HBoxContainer = CardViewScript.line_row(line.resolved(stats), "")
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _used_lines[i]:
			row.modulate.a = 0.35
		b.add_child(row)
		b.pressed.connect(func() -> void:
			if b.button_pressed:
				select_line(i)
			else:
				_selected_line = -1
				_rebuild_keeping_selection())
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
	for card in _deck:
		var holder := Control.new()
		holder.custom_minimum_size = CARD_SIZE * GRID_CARD_SCALE
		grid.add_child(holder)
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
	var action: CardAction = card.top if is_top else card.bottom
	if action == null:
		return
	if _section == Section.COLORS and _selected_color != "" and _remaining_colors.get(_selected_color, 0) > 0:
		_history.append({"type": "color", "card": card, "action": action,
			"prev_intelligence": action.intelligence, "id": _selected_color})
		DeckRules.recolor(action, _selected_color)
		_remaining_colors[_selected_color] -= 1
		if _remaining_colors[_selected_color] <= 0:
			_selected_color = ""
		_rebuild_keeping_selection()
	elif _section == Section.ACTIONS and _selected_line >= 0:
		if not DeckRules.can_add_line(action):
			_hint.text = LocalizationState.t("evolution.half_full", [DeckRules.MAX_LINES_PER_HALF])
			return
		DeckRules.add_line(action, _to.granted_lines[_selected_line])
		_history.append({"type": "line", "card": card, "action": action, "index": _selected_line})
		_used_lines[_selected_line] = true
		_selected_line = -1
		_rebuild_keeping_selection()

# ── Deshacer ────────────────────────────────────────────────────────────────

func _undo_button(type: String) -> Button:
	var b := Button.new()
	b.text = LocalizationState.t("evolution.undo")
	b.custom_minimum_size = Vector2(0, 40)
	b.disabled = not _history.any(func(op: Dictionary) -> bool: return op["type"] == type)
	b.pressed.connect(_undo.bind(type))
	return b

## Deshace el último cambio de ese tipo (color o línea).
func _undo(type: String) -> void:
	for i in range(_history.size() - 1, -1, -1):
		var op: Dictionary = _history[i]
		if op["type"] != type:
			continue
		var action: CardAction = op["action"]
		if type == "color":
			action.intelligence = op["prev_intelligence"]
			_remaining_colors[op["id"]] += 1
		else:
			DeckRules.remove_last_line(action)
			_used_lines[op["index"]] = false
		_history.remove_at(i)
		break
	_rebuild_keeping_selection()

# ── Pendientes ──────────────────────────────────────────────────────────────

## Colores que quedan por poner.
func pending_colors() -> int:
	var total := 0
	for id in _remaining_colors:
		total += _remaining_colors[id]
	return total

## Acciones que quedan por poner. Si ya no queda ninguna mitad con lugar, no
## cuentan (si no, no se podría terminar nunca).
func pending_lines() -> int:
	var has_room := _deck.any(func(c: CardData) -> bool:
		return DeckRules.can_add_line(c.top) or DeckRules.can_add_line(c.bottom))
	if not has_room:
		return 0
	return _used_lines.count(false)

func can_finish() -> bool:
	return pending_colors() == 0 and pending_lines() == 0

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
