extends Control

const MenuItem := preload("res://features/menus/main_menu/menu_item.tscn")
const COLUMNS := 3

const MENU_ITEMS := [
	{name = "Laboratorio", icon = "res://assets/icons/icon_1.png", scene = "res://features/laboratory/scene/laboratory.tscn"},
	{name = "Combate",     icon = "res://assets/icons/icon_2.png", scene = "res://features/combat/scene/combat.tscn"},
	{name = "Mazo",        icon = "res://assets/icons/icon_3.png", scene = "res://features/deck_builder/ui/deck_builder_screen.tscn"},
	{name = "Mapa",        icon = "res://assets/icons/icon_4.png", scene = ""},
	{name = "Inventario",  icon = "res://assets/icons/icon_5.png", scene = "res://features/items/ui/item_inventory_screen.tscn"},
	{name = "Guardar",     icon = "res://assets/icons/icon_6.png", scene = ""},
]

@export var overlay_mode: bool = false

@onready var grid: GridContainer = $MenuPanel/Margin/Grid
@onready var background: ColorRect = $Background
@onready var stats_bar: Panel = $StatsBar
@onready var gold_panel: PanelContainer = $GoldPanel
@onready var gold_label: Label = $GoldPanel/GoldMargin/GoldLabel

var _selected := 0
var _items: Array = []

func _ready() -> void:
	if overlay_mode:
		background.visible = false
		stats_bar.visible = false
		gold_panel.visible = true
	else:
		GameState.set_clock_visible(false)
	GameState.set_clock_paused(true)
	GameState.set_youns_status_visible(false)
	_refresh_gold()

	grid.columns = COLUMNS
	for data in MENU_ITEMS:
		var item := MenuItem.instantiate()
		grid.add_child(item)
		var tex := load(data.icon) as Texture2D if data.icon != "" else null
		item.setup(data.name, tex)
		_items.append(item)
	_update_selection()

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
		gold_label.text = "Oro: 0"
		return
	gold_label.text = "Oro: %d" % GameState.player_save.gold

func _activate() -> void:
	var scene: String = MENU_ITEMS[_selected].scene
	if scene != "":
		GameState.ui_return_scene_path = "res://features/world/game_world/game_world.tscn" if overlay_mode else ""
		get_tree().change_scene_to_file(scene)
