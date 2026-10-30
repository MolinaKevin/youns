extends Control

## Mapa de prueba dibujado desde ZoneManager.catalog. No depende de arte: toma
## las posiciones reales del mundo y muestra zonas y al jugador.


const MAP_MARGIN := 80.0
const PANEL_COLOR := Color("#10191b")
const ZONE_COLOR := Color("#29444a")
const CURRENT_ZONE_COLOR := Color("#4d896f")
const CONNECTION_COLOR := Color("#839b88")
const PLAYER_COLOR := Color("#f4d36b")
const TEST_SPAWNS_BY_ZONE := {
	"right": "TallGrassGuideTestSpawn",
}

var _map_rect := Rect2()
var _world_bounds := Rect2()
var _zone_edges: Array[Dictionary] = []
var _zone_centers: Dictionary = {}
var _close_button: Button
var _travel_button: Button
var _destination_panel: PanelContainer


func _ready() -> void:
	ModalScreenContext.enter_fullscreen(ModalScreenHost.from_runtime())
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

	_travel_button = Button.new()
	_travel_button.text = LocalizationState.t("map.travel")
	_travel_button.custom_minimum_size = Vector2(150, 42)
	_travel_button.size = _travel_button.custom_minimum_size
	_travel_button.pressed.connect(_toggle_destinations)
	add_child(_travel_button)

	_destination_panel = PanelContainer.new()
	_destination_panel.visible = false
	_destination_panel.custom_minimum_size = Vector2(240, 0)
	add_child(_destination_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_destination_panel.add_child(content)
	var heading := Label.new()
	heading.text = LocalizationState.t("map.travel_title")
	heading.add_theme_font_size_override("font_size", 20)
	content.add_child(heading)
	var hint := Label.new()
	hint.text = LocalizationState.t("map.travel_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.75, 0.84, 0.8)
	content.add_child(hint)
	var destinations := ScrollContainer.new()
	destinations.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(destinations)
	var destination_list := VBoxContainer.new()
	destination_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_list.add_theme_constant_override("separation", 4)
	destinations.add_child(destination_list)
	var zone_ids := ZoneManager.catalog.ids()
	zone_ids.sort()
	for zone_id in zone_ids:
		var destination_button := Button.new()
		destination_button.text = LocalizationState.location_name(zone_id)
		destination_button.custom_minimum_size = Vector2(210, 36)
		var spawn_name: String = TEST_SPAWNS_BY_ZONE.get(zone_id, "SpawnPoint")
		destination_button.pressed.connect(_teleport_to.bind(zone_id, spawn_name))
		destination_list.add_child(destination_button)


func _refresh_layout() -> void:
	_close_button.position = Vector2(size.x - _close_button.size.x - 28, 24)
	_travel_button.position = Vector2(_close_button.position.x - _travel_button.size.x - 12, 24)
	_destination_panel.position = Vector2(28, 105)
	_destination_panel.size = Vector2(260, maxf(280.0, size.y - 135.0))
	_world_bounds = ZoneManager.get_map_bounds()
	_zone_edges = ZoneManager.get_map_zone_edges()
	_zone_centers = ZoneManager.get_map_zone_centers()
	_map_rect = Rect2(Vector2(MAP_MARGIN, 105), size - Vector2(MAP_MARGIN * 2.0, 155))
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_toggle"):
		get_viewport().set_input_as_handled()
		_close()


func _toggle_destinations() -> void:
	_destination_panel.visible = not _destination_panel.visible


func _teleport_to(zone_id: String, spawn_name: String) -> void:
	if ZoneManager.teleport_to_zone_spawn(zone_id, spawn_name):
		_close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	if _map_rect.size.x <= 0.0 or _world_bounds.size.x <= 0.0:
		return
	draw_rect(_map_rect.grow(12.0), Color("#19292b"), true)
	draw_rect(_map_rect.grow(12.0), Color("#5a7870"), false, 2.0)
	for edge in _zone_edges:
		var is_current: bool = edge["zone"] == ZoneManager.current_zone
		var color := Color("#d0e2ca") if is_current else CONNECTION_COLOR
		draw_line(_world_point_to_map(edge["from"]), _world_point_to_map(edge["to"]), color, 2.0, true)
	for zone_id in ZoneManager.catalog.ids():
		_draw_zone_label(zone_id)

	if is_instance_valid(PartyManager.player):
		var player_pos := _world_to_map(PartyManager.player.global_position)
		draw_circle(player_pos, 9.0, Color("#1c2423"))
		draw_circle(player_pos, 6.0, PLAYER_COLOR)
		draw_arc(player_pos, 12.0, 0.0, TAU, 24, PLAYER_COLOR, 1.5, true)


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
	var world_pos := ZoneManager.catalog.definition(zone_id).offset
	return _world_to_map(world_pos)


func _world_to_map(world_pos: Vector3) -> Vector2:
	return _world_point_to_map(Vector2(world_pos.x, world_pos.z))


func _world_point_to_map(world_pos: Vector2) -> Vector2:
	var available := _map_rect.size
	var map_scale := minf(available.x / _world_bounds.size.x, available.y / _world_bounds.size.y)
	var content_size := _world_bounds.size * map_scale
	var origin := _map_rect.position + (available - content_size) * 0.5
	return origin + (world_pos - _world_bounds.position) * map_scale


func _close() -> void:
	SceneNavigator.return_to_session_origin(get_tree())
