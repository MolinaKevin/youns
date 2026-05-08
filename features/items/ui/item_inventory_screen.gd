extends Control

const ENTRY_SCENE: PackedScene = preload("res://features/items/ui/inventory_item_entry.tscn")
const COLUMNS: int = 2
const ENTRY_HEIGHT: float = 68.0
const ROW_GAP: float = 8.0
const HEADER_HEIGHT: float = 42.0
const PANEL_CHROME: float = 42.0
const MAX_VISIBLE_ROWS: int = 6

@onready var title_label: Label = $MarginContainer/WindowPanel/WindowMargin/MainVBox/Header/TitleLabel
@onready var count_label: Label = $MarginContainer/WindowPanel/WindowMargin/MainVBox/Header/CountLabel
@onready var close_button: Button = $MarginContainer/WindowPanel/WindowMargin/MainVBox/Header/CloseButton
@onready var scroll: ScrollContainer = $MarginContainer/WindowPanel/WindowMargin/MainVBox/InventoryScroll
@onready var grid: GridContainer = $MarginContainer/WindowPanel/WindowMargin/MainVBox/InventoryScroll/InventoryGrid
@onready var window_panel: Panel = $MarginContainer/WindowPanel
@onready var action_popup: Panel = $ActionPopup
@onready var popup_title: Label = $ActionPopup/Margin/VBox/PopupTitle
@onready var use_button: Button = $ActionPopup/Margin/VBox/Buttons/UseButton
@onready var drop_button: Button = $ActionPopup/Margin/VBox/Buttons/DropButton
@onready var cancel_button: Button = $ActionPopup/Margin/VBox/Buttons/CancelButton

var _selected_index := 0
var _entry_nodes: Array = []
var _popup_open := false

func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LocalizationState.language_changed.connect(_apply_localized_text)
	close_button.pressed.connect(_on_close_pressed)
	use_button.pressed.connect(_on_use_pressed)
	drop_button.pressed.connect(_on_drop_pressed)
	cancel_button.pressed.connect(_close_popup)
	_refresh_inventory()

func _unhandled_input(event: InputEvent) -> void:
	if _popup_open:
		if event.is_action_pressed("ui_cancel"):
			_close_popup()
			return
		if event.is_action_pressed("ui_accept"):
			_on_use_pressed()
			return
		return

	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		return
	if _entry_nodes.is_empty():
		return
	if event.is_action_pressed("ui_accept"):
		_open_popup()
		return
	if event.is_action_pressed("ui_left"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_right"):
		_move_selection(1)
	elif event.is_action_pressed("ui_up"):
		_move_selection(-COLUMNS)
	elif event.is_action_pressed("ui_down"):
		_move_selection(COLUMNS)

func _refresh_inventory() -> void:
	for child in grid.get_children():
		child.queue_free()
	_entry_nodes.clear()

	var capacity: int = maxi(20, GameState.player_save.inventory_slots)
	var items: Array = GameState.player_save.inventory_items

	for item in items:
		var entry = ENTRY_SCENE.instantiate()
		grid.add_child(entry)
		entry.setup(item)
		_entry_nodes.append(entry)

	title_label.text = LocalizationState.t("inventory.title")
	count_label.text = LocalizationState.t("inventory.count", [items.size(), capacity])
	_update_window_height(capacity)
	if _entry_nodes.is_empty():
		_selected_index = -1
	else:
		_selected_index = clampi(_selected_index, 0, _entry_nodes.size() - 1)
	_update_selection()

func _update_window_height(capacity: int) -> void:
	var rows := int(ceil(float(capacity) / float(COLUMNS)))
	var visible_rows: int = mini(rows, MAX_VISIBLE_ROWS)
	var content_height: float = visible_rows * ENTRY_HEIGHT + maxi(0, visible_rows - 1) * ROW_GAP
	scroll.custom_minimum_size.y = content_height
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window_panel.custom_minimum_size = Vector2(760, HEADER_HEIGHT + PANEL_CHROME + content_height)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if rows > MAX_VISIBLE_ROWS else ScrollContainer.SCROLL_MODE_DISABLED

func _move_selection(delta: int) -> void:
	var next := _selected_index + delta
	if next < 0 or next >= _entry_nodes.size():
		return
	_selected_index = next
	_update_selection()

func _update_selection() -> void:
	for i in _entry_nodes.size():
		_entry_nodes[i].set_selected(i == _selected_index)
	if _selected_index >= 0 and _selected_index < _entry_nodes.size():
		scroll.ensure_control_visible(_entry_nodes[_selected_index])

func _open_popup() -> void:
	if _selected_index < 0 or _selected_index >= GameState.player_save.inventory_items.size():
		return
	var item: Dictionary = GameState.player_save.inventory_items[_selected_index]
	popup_title.text = LocalizationState.item_name(
		str(item.get("id", "")),
		str(item.get("name", LocalizationState.t("inventory.item_default")))
	)
	action_popup.visible = true
	_popup_open = true
	use_button.grab_focus()

func _close_popup() -> void:
	action_popup.visible = false
	_popup_open = false

func _on_use_pressed() -> void:
	_drop_selected_item()

func _on_drop_pressed() -> void:
	_drop_selected_item()

func _drop_selected_item() -> void:
	if _selected_index < 0 or _selected_index >= GameState.player_save.inventory_items.size():
		_close_popup()
		return
	var items: Array = GameState.player_save.inventory_items
	var item: Dictionary = items[_selected_index]
	var count: int = int(item.get("count", 1))
	if count > 1:
		item["count"] = count - 1
		items[_selected_index] = item
	else:
		items.remove_at(_selected_index)
	GameState.player_save.inventory_items = items
	GameState.save_player_save()
	_close_popup()
	_refresh_inventory()

func _on_close_pressed() -> void:
	get_tree().change_scene_to_file("res://features/world/game_world/game_world.tscn")

func _apply_localized_text(_language: String = "") -> void:
	title_label.text = LocalizationState.t("inventory.title")
	close_button.text = LocalizationState.t("inventory.close")
	use_button.text = LocalizationState.t("inventory.use")
	drop_button.text = LocalizationState.t("inventory.drop")
	cancel_button.text = LocalizationState.t("inventory.cancel")
