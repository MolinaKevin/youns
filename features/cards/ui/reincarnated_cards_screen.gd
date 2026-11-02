extends Control

## Listado de cartas reencarnadas: la carta que heredó cada huevo
## (PlayerSaveData.saved_cards). Se desbloquea con la primera reencarnación y
## se abre desde el menú del juego.

func _ready() -> void:
	ModalScreenContext.enter_fullscreen(ModalScreenHost.from_runtime())
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = LocalizationState.t("reincarnated.title")
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)

	var hint := Label.new()
	hint.text = LocalizationState.t("reincarnated.hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

	# "Volver" abajo (arriba a la derecha lo tapa el panel de debug).
	var back := Button.new()
	back.text = LocalizationState.t("reincarnated.back")
	back.custom_minimum_size = Vector2(160, 44)
	back.pressed.connect(_on_back)

	var save := PlayerSessionAccess.save()
	var cards: Array[CardData] = save.saved_cards if save != null else ([] as Array[CardData])
	if cards.is_empty():
		var empty := Label.new()
		empty.text = LocalizationState.t("reincarnated.empty")
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(empty)
		column.add_child(back)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	for card in cards:
		var view := CardGridEntry.build(grid, card)
		view.set_disabled(true)
	column.add_child(back)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_back() -> void:
	SceneNavigator.return_to_origin(get_tree())
