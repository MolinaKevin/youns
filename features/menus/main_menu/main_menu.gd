extends Control

const MenuItem := preload("res://features/menus/main_menu/menu_item.tscn")
const COLUMNS := 3

const MENU_ITEMS := [
	{name_key = "main_menu.lab",       icon = "res://assets/icons/icon_1.png", scene = "res://features/laboratory/scene/laboratory.tscn"},
	{name_key = "main_menu.deck",      icon = "res://assets/icons/icon_3.png", scene = "res://features/deck_builder/ui/deck_builder_screen.tscn"},
	{name_key = "main_menu.map",       icon = "res://assets/icons/icon_4.png", scene = "res://features/map/ui/technical_map.tscn"},
	{name_key = "main_menu.inventory", icon = "res://assets/icons/icon_5.png", scene = "res://features/items/ui/item_inventory_screen.tscn"},
	{name_key = "main_menu.sleep",     icon = "res://assets/icons/icon_6.png", scene = ""},
	{name_key = "main_menu.evolutions", icon = "res://assets/icons/icon_4.png", scene = "res://features/world/evolution/evolution_tree_screen.tscn"},
	# Solo después de la primera reencarnación (ver _is_item_unlocked).
	{name_key = "main_menu.reincarnated_cards", icon = "res://assets/icons/icon_3.png", scene = "res://features/cards/ui/reincarnated_cards_screen.tscn", unlock = "reincarnated_cards"},
]

const SLEEP_ITEM_INDEX := 4

signal sleep_requested

@export var overlay_mode: bool = false

@onready var grid: GridContainer = $MenuPanel/Margin/Grid
@onready var background: ColorRect = $Background
@onready var stats_bar: Panel = $StatsBar
@onready var gold_panel: PanelContainer = $GoldPanel
@onready var gold_label: Label = $GoldPanel/GoldMargin/GoldLabel
@onready var year_label: Label = $StatsBar/HBox/YearLabel
@onready var day_label: Label = $StatsBar/HBox/DayLabel

var _selected := 0
var _items: Array = []
var _item_textures: Array[Texture2D] = []

func _ready() -> void:
	if overlay_mode:
		background.visible = false
		stats_bar.visible = false
		gold_panel.visible = true
	else:
		GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	LocalizationState.language_changed.connect(_apply_localized_text)
	GameState.clock_changed.connect(_on_clock_changed)
	_refresh_gold()

	grid.columns = COLUMNS
	_build_items()
	# Se rearma al abrirse: un ítem se pudo desbloquear jugando.
	visibility_changed.connect(func() -> void:
		if visible:
			_build_items())

func _build_items() -> void:
	for item in _items:
		grid.remove_child(item)
		item.queue_free()
	_items.clear()
	_item_textures.clear()
	for data in MENU_ITEMS:
		# Los ítems bloqueados van al final de la lista: saltearlos no corre los índices.
		if not _is_item_unlocked(data):
			continue
		var item := MenuItem.instantiate()
		grid.add_child(item)
		var tex := load(data.icon) as Texture2D if data.icon != "" else null
		item.setup(LocalizationState.t(data.name_key), tex)
		_items.append(item)
		_item_textures.append(tex)
	_selected = mini(_selected, _items.size() - 1)
	_apply_localized_text()
	_update_sleep_state()
	_update_selection()

func _is_item_unlocked(data: Dictionary) -> bool:
	match data.get("unlock", ""):
		"reincarnated_cards":
			return GameState.player_save != null and GameState.player_save.reincarnated_cards_unlocked
	return true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(COLUMNS)
	elif event.is_action_pressed("ui_up"):
		_move(-COLUMNS)
	elif event.is_action_pressed("ui_accept"):
		_activate()

func _move(delta: int) -> void:
	var next := _selected + delta
	if next < 0 or next >= _items.size():
		return
	_selected = next
	_update_selection()

func _update_selection() -> void:
	for i in _items.size():
		_items[i].set_selected(i == _selected)

func _refresh_gold() -> void:
	if GameState.player_save == null:
		gold_label.text = LocalizationState.t("main_menu.gold", [0])
		return
	gold_label.text = LocalizationState.t("main_menu.gold", [GameState.player_save.gold])

func _apply_localized_text(_language: String = "") -> void:
	for index in _items.size():
		_items[index].setup(LocalizationState.t(MENU_ITEMS[index].name_key), _item_textures[index])
	var current_day := maxi(GameState.current_day, 1)
	var current_year := floori(float(current_day - 1) / 365.0) + 1
	var day_of_year := ((current_day - 1) % 365) + 1
	year_label.text = LocalizationState.t("main_menu.year", [current_year])
	day_label.text = LocalizationState.t("main_menu.day", [day_of_year])
	_refresh_gold()

func _activate() -> void:
	if _selected == SLEEP_ITEM_INDEX:
		if _is_sleep_time():
			sleep_requested.emit()
		return
	var scene: String = MENU_ITEMS[_selected].scene
	if scene != "":
		GameState.ui_return.set_return("res://features/world/game_world/game_world.tscn" if overlay_mode else "")
		get_tree().paused = false
		get_tree().change_scene_to_file(scene)

func _is_sleep_time() -> bool:
	var youn_node = PartyManager.youn if PartyManager else null
	if not is_instance_valid(youn_node) or youn_node.youn_data == null:
		return false
	var data: YounData = youn_node.youn_data
	var hour: float = GameState.time_of_day_hours
	if data.sleep_hour > data.wake_hour:
		return hour >= data.sleep_hour or hour < data.wake_hour
	return hour >= data.sleep_hour and hour < data.wake_hour

func _update_sleep_state() -> void:
	if _items.size() > SLEEP_ITEM_INDEX:
		_items[SLEEP_ITEM_INDEX].set_disabled(not _is_sleep_time())

func _on_clock_changed(_hour: float, _day: int) -> void:
	_update_sleep_state()
