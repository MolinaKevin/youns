extends Control

## Mapa de prueba dibujado desde ZoneManager.ZONES. No depende de arte: toma
## las posiciones reales del mundo y muestra zonas y al jugador.

const GAME_WORLD := "res://features/world/game_world/game_world.tscn"
const TITLE_MENU := "res://features/menus/main_menu/title_menu.tscn"

const MAP_MARGIN := 80.0
const PANEL_COLOR := Color("#10191b")
const ZONE_COLOR := Color("#29444a")
const CURRENT_ZONE_COLOR := Color("#4d896f")
const CONNECTION_COLOR := Color("#839b88")
const PLAYER_COLOR := Color("#f4d36b")
const FUTURE_AREA_FILL := Color("#182426")
const FUTURE_AREA_BORDER := Color("#71877d")

# Espacio reservado para que la ciudad pueda expandirse detrás del río. Es
# cartografía solamente: no abre una zona ni habilita el paso en el mundo.
const FUTURE_AREAS := [
	{
		"rect": Rect2(-195, -65, 145, 150),
		"label_key": "map.future.city_expansion",
	},
]

var _map_rect := Rect2()
var _world_bounds := Rect2()
var _zone_edges: Array[Dictionary] = []
var _zone_centers: Dictionary = {}
var _close_button: Button


func _ready() -> void:
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	resized.connect(_refresh_layout)
	_refresh_layout()


func _build_ui() -> void:
	var title := Label.new()
	title.text = LocalizationState.t("map.technical_title")
	title.position = Vector2(32, 22)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = LocalizationState.t("map.technical_hint")
	subtitle.position = Vector2(34, 58)
	subtitle.modulate = Color(0.75, 0.84, 0.8)
	add_child(subtitle)

	_close_button = Button.new()
	_close_button.text = LocalizationState.t("map.close")
	_close_button.custom_minimum_size = Vector2(130, 42)
	_close_button.size = _close_button.custom_minimum_size
	_close_button.pressed.connect(_close)
	add_child(_close_button)


func _refresh_layout() -> void:
	_close_button.position = Vector2(size.x - _close_button.size.x - 28, 24)
	_world_bounds = ZoneManager.get_map_bounds()
	_zone_edges = ZoneManager.get_map_zone_edges()
	_zone_centers = ZoneManager.get_map_zone_centers()
	_map_rect = Rect2(Vector2(MAP_MARGIN, 105), size - Vector2(MAP_MARGIN * 2.0, 155))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_toggle"):
		get_viewport().set_input_as_handled()
		_close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	if _map_rect.size.x <= 0.0 or _world_bounds.size.x <= 0.0:
		return
	draw_rect(_map_rect.grow(12.0), Color("#19292b"), true)
	draw_rect(_map_rect.grow(12.0), Color("#5a7870"), false, 2.0)
	for area in FUTURE_AREAS:
		_draw_future_area(area)

	for edge in _zone_edges:
		var is_current: bool = edge["zone"] == ZoneManager.current_zone
		var color := Color("#d0e2ca") if is_current else CONNECTION_COLOR
		draw_line(_world_point_to_map(edge["from"]), _world_point_to_map(edge["to"]), color, 2.0, true)
	for zone_id in ZoneManager.ZONES:
		_draw_zone_label(zone_id)

	if is_instance_valid(PartyManager.player):
		var player_pos := _world_to_map(PartyManager.player.global_position)
		draw_circle(player_pos, 9.0, Color("#1c2423"))
		draw_circle(player_pos, 6.0, PLAYER_COLOR)
		draw_arc(player_pos, 12.0, 0.0, TAU, 24, PLAYER_COLOR, 1.5, true)


func _draw_future_area(area: Dictionary) -> void:
	var world_rect: Rect2 = area["rect"]
	var map_rect := _world_rect_to_map(world_rect)
	draw_rect(map_rect, FUTURE_AREA_FILL, true)
	draw_rect(map_rect, FUTURE_AREA_BORDER, false, 2.0)
	var label_key: String = area["label_key"]
	var label := LocalizationState.t(label_key)
	var font := ThemeDB.fallback_font
	var font_size := 16
	var lines := label.split("\n")
	var first_baseline := map_rect.get_center().y - (lines.size() - 1) * font_size * 0.6
	for line_index in lines.size():
		var text_position := Vector2(map_rect.position.x + 10.0, first_baseline + line_index * font_size * 1.2)
		draw_string(font, text_position, lines[line_index], HORIZONTAL_ALIGNMENT_CENTER, map_rect.size.x - 20.0, font_size, FUTURE_AREA_BORDER)


func _draw_zone_label(zone_id: String) -> void:
	var center := _zone_center(zone_id)
	var location_name := LocalizationState.location_name(zone_id)
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(location_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - text_size * 0.5, location_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _zone_center(zone_id: String) -> Vector2:
	if _zone_centers.has(zone_id):
		return _world_point_to_map(_zone_centers[zone_id])
	var world_pos: Vector3 = ZoneManager.ZONES[zone_id]["offset"]
	return _world_to_map(world_pos)


func _world_to_map(world_pos: Vector3) -> Vector2:
	return _world_point_to_map(Vector2(world_pos.x, world_pos.z))


func _world_point_to_map(world_pos: Vector2) -> Vector2:
	var available := _map_rect.size
	var map_scale := minf(available.x / _world_bounds.size.x, available.y / _world_bounds.size.y)
	var content_size := _world_bounds.size * map_scale
	var origin := _map_rect.position + (available - content_size) * 0.5
	return origin + (world_pos - _world_bounds.position) * map_scale


func _world_rect_to_map(world_rect: Rect2) -> Rect2:
	var top_left := _world_point_to_map(world_rect.position)
	var bottom_right := _world_point_to_map(world_rect.end)
	return Rect2(top_left, bottom_right - top_left)


func _close() -> void:
	get_tree().paused = false
	if GameState.ui_return_scene_path != "":
		var return_scene: String = GameState.ui_return_scene_path
		GameState.ui_return_scene_path = ""
		get_tree().change_scene_to_file(return_scene)
		return
	get_tree().change_scene_to_file(TITLE_MENU if not GameState.session_active else GAME_WORLD)
