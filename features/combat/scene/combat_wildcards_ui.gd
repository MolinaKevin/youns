class_name CombatWildcardsUI
extends RefCounted

signal wild_toggled(wild: int, pressed: bool)
signal skip_requested
signal end_turn_requested
signal keep_card_selected(card: CardData)
signal item_selected(inventory_index: int, data: ItemData)
signal item_cancelled

var panel: PanelContainer
var _buttons: Dictionary = {}
var _title: Label
var _lines: Label
var _skip: Button
var _end: Button
var _item_picker: PanelContainer
var _item_list: VBoxContainer
var _item_title: Label
var _item_cancel: Button
var _pile_popup: Control
var _pile_title: Label
var _pile_grid
var _showing_keep := false
var _wilds: Dictionary = {}
var _shown_items: Array = []

func setup(hand, ui_root: Node, pile_popup: Control, pile_title: Label, pile_grid, wilds: Dictionary) -> void:
	_wilds = wilds
	_pile_popup = pile_popup
	_pile_title = pile_title
	_pile_grid = pile_grid
	_pile_grid.card_selected.connect(func(card): if _showing_keep: keep_card_selected.emit(card))
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.12, 0.92)
	style.border_color = Color(0.35, 0.85, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	hand.set_middle_control(panel)
	_title = Label.new(); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(_title)
	for wild in [_wilds["attack"], _wilds["move"], _wilds["keep"], _wilds["item"]]:
		var button := Button.new()
		button.toggle_mode = true; button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_constant_override("icon_max_width", 22)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT; button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("h_separation", 8)
		button.toggled.connect(_on_wild_toggled.bind(wild))
		column.add_child(button); _buttons[wild] = button
	column.add_child(HSeparator.new())
	_lines = Label.new(); _lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(_lines)
	_skip = Button.new(); _skip.custom_minimum_size = Vector2(0, 40); _skip.pressed.connect(skip_requested.emit); column.add_child(_skip)
	_end = Button.new(); _end.custom_minimum_size = Vector2(0, 44); _end.pressed.connect(end_turn_requested.emit); column.add_child(_end)
	panel.visible = false
	_build_item_picker(ui_root)

func apply_localization(wild_attack: CardAction, wild_move: CardAction) -> void:
	_title.text = LocalizationState.t("combat.wildcards")
	_set_button(_wilds["attack"], "sword", "▲  %d" % wild_attack.lines[0].damage, LocalizationState.t("wildcard.attack", [wild_attack.lines[0].damage]))
	var modules := roundi(wild_move.lines[0].movement_effective_modules())
	_set_button(_wilds["move"], "move", "▼  %s" % wild_move.lines[0].movement_module_label(), LocalizationState.t("wildcard.move", [modules]))
	_set_button(_wilds["keep"], "keep", "▲▼  " + LocalizationState.t("wildcard.keep"), LocalizationState.t("wildcard.keep"))
	_set_button(_wilds["item"], "heal", "▲▼  " + LocalizationState.t("wildcard.item"), LocalizationState.t("wildcard.item_tooltip"))
	_end.text = LocalizationState.t("combat.end_turn"); _skip.text = LocalizationState.t("combat.skip_line")
	_item_cancel.text = LocalizationState.t("combat.item_cancel")
	_item_title.text = LocalizationState.t("combat.item_title")
	if _showing_keep:
		_pile_title.text = LocalizationState.t("combat.keep_title")
	if _item_picker.visible:
		_refresh_item_picker()

func update_state(is_acting: bool, armed: int, usable: Dictionary, playing: Dictionary, both_used: bool) -> bool:
	panel.visible = is_acting
	for wild in _buttons: _buttons[wild].disabled = not usable[wild]
	_skip.disabled = playing.is_empty() or not playing["active"]
	_lines.visible = not playing.is_empty() and not playing["wild"]
	if _lines.visible: _lines.text = LocalizationState.t("combat.lines_used", [playing["used"], playing["cap"]])
	_end.modulate = Color(1.0, 0.85, 0.35) if both_used else Color.WHITE
	return armed != _wilds["none"] and not usable[armed]

func disarm() -> void:
	for button in _buttons.values(): button.set_pressed_no_signal(false)

func show_keep_picker(cards: Array[CardData]) -> void:
	_showing_keep = true; _pile_title.text = LocalizationState.t("combat.keep_title"); _pile_grid.set_cards(cards); _pile_popup.visible = true

func close_keep_picker() -> void:
	_showing_keep = false

func show_item_picker(items: Array) -> void:
	_shown_items.assign(items)
	_refresh_item_picker()
	_item_picker.visible = true

func _refresh_item_picker() -> void:
	_item_title.text = LocalizationState.t("combat.item_title")
	for child in _item_list.get_children(): child.queue_free()
	for item in _shown_items:
		var data: ItemData = item["data"]
		var button := Button.new()
		button.text = "%s  ×%d" % [LocalizationState.item_name(data.id, data.name), item["count"]]
		button.tooltip_text = data.description; button.icon = data.icon; button.expand_icon = true
		button.custom_minimum_size = Vector2(0, 40); button.add_theme_constant_override("icon_max_width", 28); button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(item_selected.emit.bind(item["index"], data)); _item_list.add_child(button)

func close_item_picker() -> void:
	if _item_picker != null: _item_picker.visible = false

func hide() -> void:
	panel.visible = false; close_item_picker(); close_keep_picker()

func _on_wild_toggled(pressed: bool, wild: int) -> void:
	if pressed:
		for key in _buttons:
			if key != wild: _buttons[key].set_pressed_no_signal(false)
	wild_toggled.emit(wild, pressed)

func _set_button(wild: int, icon_key: String, text: String, tooltip: String) -> void:
	var button: Button = _buttons[wild]
	button.icon = CardText.icon(icon_key); button.text = text; button.tooltip_text = tooltip

func _build_item_picker(ui_root: Node) -> void:
	_item_picker = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.12, 0.96)
	style.border_color = Color(0.35, 0.85, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	_item_picker.add_theme_stylebox_override("panel", style)
	_item_picker.custom_minimum_size = Vector2(320, 0); _item_picker.set_anchors_preset(Control.PRESET_CENTER)
	_item_picker.grow_horizontal = Control.GROW_DIRECTION_BOTH; _item_picker.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 8); _item_picker.add_child(column)
	_item_title = Label.new(); _item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(_item_title)
	_item_list = VBoxContainer.new(); _item_list.add_theme_constant_override("separation", 6); column.add_child(_item_list)
	_item_cancel = Button.new(); _item_cancel.text = LocalizationState.t("combat.item_cancel"); _item_cancel.pressed.connect(item_cancelled.emit); column.add_child(_item_cancel)
	_item_picker.visible = false; ui_root.add_child(_item_picker)
