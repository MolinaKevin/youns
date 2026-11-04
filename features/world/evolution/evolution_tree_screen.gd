class_name EvolutionTreeScreen
extends Control

## Árbol de evoluciones: los Youns por etapa (bebé → ultimate), en casilleros
## cuadrados con su ícono (como una chart: una columna de color por etapa, sin
## líneas que las conecten). Los descubiertos (PlayerSaveData.discovered_evolutions,
## más el Youn actual) muestran su retrato (o su nombre si todavía no tiene);
## el resto queda vacío/bloqueado. Tocar uno descubierto muestra sus
## inteligencias y sus condiciones: las conocidas con texto y las demás como
## "???????". Se abre desde el menú del juego.

const Intelligences := preload("res://data/youns/intelligences.gd")
const YounCatalogScript := preload("res://shared/youn_catalog.gd")
const STAGES := ["bebe", "nino", "adolescente", "campeon", "ultimate"]
const NODE_SIZE := Vector2(80, 80)
const BG := Color(0.03, 0.06, 0.09)
const PANEL_BG := Color(0.05, 0.1, 0.15)
const KNOWN := EvolutionPalette.ACCENT
const HIDDEN := Color(0.3, 0.33, 0.36)
const CURRENT := EvolutionPalette.CURRENT
## Tinte de fondo por etapa, como las columnas de color de una chart de
## evolución: cada etapa se distingue de un vistazo aunque le falten Youns.
const STAGE_TINTS := {
	"bebe": Color(0.45, 0.2, 0.28, 0.35),
	"nino": Color(0.32, 0.18, 0.42, 0.35),
	"adolescente": Color(0.14, 0.26, 0.42, 0.35),
	"campeon": Color(0.14, 0.38, 0.24, 0.35),
	"ultimate": Color(0.48, 0.32, 0.12, 0.35),
}
## Casilleros a reservar por etapa (más que los Youns que hay hoy): deja el
## resto vacíos para cuando se agreguen. Ajustar acá a medida que se diseñen
## más Youns de una etapa.
const STAGE_CAPACITY := {
	"bebe": 4,
	"nino": 5,
	"adolescente": 9,
	"campeon": 50,
	"ultimate": 15,
}
## Columnas de la grilla por etapa: bebé/niño/adolescente angostos (una sola
## columna) para dejarle ancho a campeón/ultimate, que si no desbordan mucho
## más en vertical dentro del mismo alto de pantalla.
const STAGE_COLUMNS := {
	"bebe": 1,
	"nino": 1,
	"adolescente": 1,
	"campeon": 6,
	"ultimate": 2,
}

var _youns: Array[YounData] = []
var _discovered := {}
var _current_path := ""
## Botón de cada Youn (por resource_path), para la navegación por teclado.
var _nodes := {}
var _detail: EvolutionDetailOverlay
var _focus_nav: EvolutionFocusNav

func _ready() -> void:
	ModalScreenContext.enter_fullscreen(ModalScreenHost.from_runtime())
	_detail = EvolutionDetailOverlay.new(self)
	_focus_nav = EvolutionFocusNav.new(self)
	_load_youns()
	_build()
	_focus_nav.focus_initial.call_deferred()

func _load_youns() -> void:
	var save := PlayerSessionAccess.save()
	if save != null:
		_current_path = save.current_youn_path
		for key in save.discovered_evolutions:
			_discovered[key] = true
	for data in YounCatalogScript.all():
		if data == null or not data.stage in STAGES:
			continue
		# Los salvajes sueltos (sin etapa propia ni evoluciones) no van.
		if data.stage == "bebe" and data.evolves_to.is_empty() and data.starting_deck.is_empty():
			continue
		_youns.append(data)

func _is_discovered(data: YounData) -> bool:
	return data.resource_path == _current_path or _discovered.has(EvolutionDiscovery.youn_key(data))

## API para los helpers del árbol: evita exponer su almacenamiento interno.
func current_evolution_node() -> Button:
	return _nodes.get(_current_path) as Button

func evolution_node_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for node in _nodes.values():
		var button := node as Button
		if button != null:
			buttons.append(button)
	return buttons

func is_current_youn(data: YounData) -> bool:
	return data.resource_path == _current_path

func restore_tree_focus() -> void:
	_focus_nav.restore_focus()

# ── Armado ───────────────────────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = LocalizationState.t("tree.title")
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	# Árbol: una columna por etapa, cada una con su color y una grilla de
	# casilleros cuadrados, del tamaño justo para sus cupos (sin estirarse
	# todas a la misma altura). Sin líneas entre evoluciones (chart, no árbol).
	var tree_scroll := ScrollContainer.new()
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(tree_scroll)
	var stages_row := HBoxContainer.new()
	stages_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages_row.add_theme_constant_override("separation", 18)
	tree_scroll.add_child(stages_row)
	for stage in STAGES:
		stages_row.add_child(_stage_column(stage))

	_detail.build()

	var back := Button.new()
	back.text = LocalizationState.t("reincarnated.back")
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(_on_back)
	column.add_child(back)

func _stage_column(stage: String) -> PanelContainer:
	var stage_youns: Array[YounData] = []
	for data in _youns:
		if data.stage == stage:
			stage_youns.append(data)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = STAGE_TINTS.get(stage, Color(0.1, 0.1, 0.12, 0.35))
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)

	var capacity: int = maxi(stage_youns.size(), STAGE_CAPACITY.get(stage, stage_youns.size()))
	var grid := GridContainer.new()
	grid.columns = STAGE_COLUMNS.get(stage, 1)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	inner.add_child(grid)
	for data in stage_youns:
		grid.add_child(_node_button(data))
	for i in capacity - stage_youns.size():
		grid.add_child(_empty_slot())
	return panel

## Casillero reservado sin Youn asignado todavía: no es interactivo ni entra
## en la navegación por teclado, solo marca que hay lugar para más.
func _empty_slot() -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = NODE_SIZE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.09, 0.1, 0.35)
	st.border_color = HIDDEN
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	slot.add_theme_stylebox_override("panel", st)
	return slot

func _node_button(data: YounData) -> Button:
	var known := _is_discovered(data)
	var b := Button.new()
	b.custom_minimum_size = NODE_SIZE
	b.disabled = not known
	if known and data.portrait != null:
		b.icon = data.portrait
		b.expand_icon = true
	elif known:
		b.text = data.youn_name
		b.add_theme_font_size_override("font_size", 13)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL_BG if known else Color(0.08, 0.09, 0.1, 0.6)
	st.border_color = CURRENT if data.resource_path == _current_path else (KNOWN if known else HIDDEN)
	st.set_border_width_all(3 if data.resource_path == _current_path else 1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(6)
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, st)
	var hover := st.duplicate()
	hover.bg_color = Color(0.1, 0.22, 0.3)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(_detail.show_for.bind(data))
	b.focus_entered.connect(_focus_nav.on_node_focused.bind(b))
	_nodes[data.resource_path] = b
	return b

func _unhandled_input(event: InputEvent) -> void:
	if not _detail.is_open():
		if event.is_action_pressed("ui_left"):
			get_viewport().set_input_as_handled()
			_focus_nav.move(Vector2.LEFT)
			return
		if event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			_focus_nav.move(Vector2.RIGHT)
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			_focus_nav.move(Vector2.UP)
			return
		if event.is_action_pressed("ui_down"):
			get_viewport().set_input_as_handled()
			_focus_nav.move(Vector2.DOWN)
			return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _detail.is_open():
			_detail.close_overlay()
		else:
			_on_back()

func _on_back() -> void:
	SceneNavigator.return_to_origin(get_tree())
