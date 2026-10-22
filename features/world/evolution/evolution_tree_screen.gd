extends Control

## Árbol de evoluciones: los Youns por etapa (bebé → ultimate). Los descubiertos
## (PlayerSaveData.discovered_evolutions, más el Youn actual) muestran su
## nombre; el resto, "???". Tocar uno descubierto muestra sus inteligencias y
## sus condiciones: las conocidas con texto y las demás como "???????".
## Se abre desde el menú del juego.

const Intelligences := preload("res://data/youns/intelligences.gd")
const YOUNS_DIR := "res://data/youns/"
const STAGES := ["bebe", "nino", "adolescente", "campeon", "ultimate"]
const GAME_WORLD := "res://features/world/game_world/game_world.tscn"
const NODE_SIZE := Vector2(150, 54)
const BG := Color(0.03, 0.06, 0.09)
const PANEL_BG := Color(0.05, 0.1, 0.15)
const KNOWN := Color(0.35, 0.85, 1.0)
const HIDDEN := Color(0.3, 0.33, 0.36)
const CURRENT := Color(1.0, 0.85, 0.35)
const LINK := Color(0.35, 0.85, 1.0, 0.5)

var _youns: Array[YounData] = []
var _discovered := {}
var _current_path := ""
## Botón de cada Youn (por resource_path), para dibujar las líneas.
var _nodes := {}
var _links: Control
var _detail: EvolutionDetailOverlay
var _focus_nav: EvolutionFocusNav

func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_detail = EvolutionDetailOverlay.new(self)
	_focus_nav = EvolutionFocusNav.new(self)
	_load_youns()
	_build()
	_focus_nav.focus_initial.call_deferred()

func _load_youns() -> void:
	var save := GameState.player_save
	if save != null:
		_current_path = save.current_youn_path
		for key in save.discovered_evolutions:
			_discovered[key] = true
	var dir := DirAccess.open(YOUNS_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var data := load(YOUNS_DIR + file) as YounData
		if data == null or not data.stage in STAGES:
			continue
		# Los salvajes sueltos (sin etapa propia ni evoluciones) no van.
		if data.stage == "bebe" and data.evolves_to.is_empty() and data.starting_deck.is_empty():
			continue
		_youns.append(data)

func _is_discovered(data: YounData) -> bool:
	return data.resource_path == _current_path or _discovered.has(EvolutionDiscovery.youn_key(data))

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

	# Árbol arriba (todo el ancho) y el detalle abajo.
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	# Árbol: una columna por etapa, con las líneas dibujadas por detrás.
	var tree_area := Control.new()
	tree_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tree_area)
	_links = Control.new()
	_links.set_anchors_preset(Control.PRESET_FULL_RECT)
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.draw.connect(_draw_links)
	tree_area.add_child(_links)
	var stages_row := HBoxContainer.new()
	stages_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	stages_row.add_theme_constant_override("separation", 24)
	tree_area.add_child(stages_row)
	for stage in STAGES:
		var stage_col := VBoxContainer.new()
		stage_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage_col.add_theme_constant_override("separation", 14)
		stage_col.alignment = BoxContainer.ALIGNMENT_CENTER
		stages_row.add_child(stage_col)
		var header := Label.new()
		header.text = LocalizationState.youn_stage_name(stage)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage_col.add_child(header)
		for data in _youns:
			if data.stage == stage:
				stage_col.add_child(_node_button(data))

	_detail.build()

	var back := Button.new()
	back.text = LocalizationState.t("reincarnated.back")
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(_on_back)
	column.add_child(back)
	# Las líneas se dibujan cuando los botones ya tienen su lugar.
	_links.queue_redraw.call_deferred()
	resized.connect(_links.queue_redraw)

func _node_button(data: YounData) -> Button:
	var known := _is_discovered(data)
	var b := Button.new()
	b.custom_minimum_size = NODE_SIZE
	b.text = data.youn_name if known else "???"
	b.disabled = not known
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL_BG if known else Color(0.08, 0.09, 0.1)
	st.border_color = CURRENT if data.resource_path == _current_path else (KNOWN if known else HIDDEN)
	st.set_border_width_all(3 if data.resource_path == _current_path else 1)
	st.set_corner_radius_all(8)
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

## Líneas entre Youns descubiertos: las evoluciones fijas (evolves_to) y, como
## a un campeón se llega desde cualquier rookie, rookie → campeón.
func _draw_links() -> void:
	for data in _youns:
		if not _is_discovered(data):
			continue
		var targets: Array[String] = []
		targets.append_array(data.evolves_to)
		if data.stage == "adolescente":
			for other in _youns:
				if other.stage == "campeon":
					targets.append(other.resource_path)
		for path in targets:
			if not _nodes.has(path) or not _nodes.has(data.resource_path):
				continue
			var target: YounData = null
			for other in _youns:
				if other.resource_path == path:
					target = other
			if target == null or not _is_discovered(target):
				continue
			var a: Button = _nodes[data.resource_path]
			var b: Button = _nodes[path]
			var from := _links.get_global_transform().affine_inverse() * (a.global_position + Vector2(a.size.x, a.size.y * 0.5))
			var to := _links.get_global_transform().affine_inverse() * (b.global_position + Vector2(0, b.size.y * 0.5))
			_links.draw_line(from, to, LINK, 2.0, true)

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
	get_tree().change_scene_to_file(GAME_WORLD)
