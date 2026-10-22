class_name EvolutionDetailOverlay
extends RefCounted

## Panel modal con el detalle de un Youn del árbol de evoluciones: sus
## inteligencias y sus condiciones de evolución (las conocidas con texto, el
## resto "???????"). `host` es la pantalla (EvolutionTreeScreen, sin
## class_name propio) dueña exclusiva de esta instancia.

var host

var overlay: Control
var _portrait: TextureRect
var _info: VBoxContainer

func _init(p_host) -> void:
	host = p_host

func build() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	host.add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.94)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.04
	panel.anchor_top = 0.05
	panel.anchor_right = 0.96
	panel.anchor_bottom = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color = host.PANEL_BG
	style.border_color = host.KNOWN
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	panel.add_child(content)
	var portrait_square := AspectRatioContainer.new()
	portrait_square.ratio = 1.0
	portrait_square.stretch_mode = AspectRatioContainer.STRETCH_FIT
	portrait_square.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_square.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(portrait_square)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_square.add_child(_portrait)
	var info_scroll := ScrollContainer.new()
	info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(info_scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 12)
	info_scroll.add_child(_info)

func is_open() -> bool:
	return overlay.visible

func show_for(data: YounData) -> void:
	for child in _info.get_children():
		child.queue_free()
	_portrait.texture = data.portrait
	_portrait.visible = data.portrait != null
	overlay.visible = true
	var close := Button.new()
	close.text = "Volver al árbol"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(close_overlay)
	_info.add_child(close)
	_info.add_child(_text(data.youn_name, 32, Color.WHITE))
	_info.add_child(_text(LocalizationState.youn_stage_name(data.stage), 18, Color(0.7, 0.75, 0.8)))
	if data.resource_path == host._current_path:
		_info.add_child(_text(LocalizationState.t("tree.current"), 15, host.CURRENT))
	if not data.intelligences.is_empty():
		var names: PackedStringArray = []
		for id in data.intelligences:
			names.append(host.Intelligences.display_name(id))
		_info.add_child(_text(LocalizationState.t("tree.intelligences", [", ".join(names)]), 16, host.KNOWN))
	_info.add_child(HSeparator.new())
	if data.is_wildcard:
		_info.add_child(_text(LocalizationState.t("evolution.wildcard"), 15, Color.WHITE))
		return
	if data.evolution_conditions.is_empty():
		_info.add_child(_text(LocalizationState.t("evolution.no_conditions"), 15, Color.WHITE))
		return
	_info.add_child(_text(LocalizationState.t("tree.conditions"), 16, Color.WHITE))
	var known: Array = GameState.player_save.discovered_evolutions.get(EvolutionDiscovery.youn_key(data), [])
	for i in data.evolution_conditions.size():
		if known.has(i):
			_info.add_child(_text("• " + data.evolution_conditions[i].describe(), 15, host.CURRENT))
		else:
			_info.add_child(_text("• ???????", 15, host.HIDDEN))

func close_overlay() -> void:
	overlay.visible = false
	if host._focus_nav.focused != null:
		host._focus_nav.focused.call_deferred("grab_focus")

func _text(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
