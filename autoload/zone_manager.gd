extends Node

const WorldBoundary := preload("res://features/world/zones/world_boundary.gd")
const ScenePaths := preload("res://shared/scene_paths.gd")
const TITLE_MENU_SCENE := ScenePaths.TITLE_MENU

signal zone_changed(previous_zone: String, current_zone: String)
signal zone_loaded(zone_id: String)
signal zone_unloaded(zone_id: String)

var catalog: ZoneCatalog = ZoneCatalog.new()

var _initial_zone := "hub"
var current_zone: String:
	get:
		return _presence.current_zone if is_instance_valid(_presence) else _initial_zone
var _interiors: InteriorTransitionController
var _streaming: ZoneStreamingController
var _presence: ZonePresenceTracker
var navigation: WorldNavigationService = WorldNavigationService.new()
var _boundary: Node3D = null   # paredes y bosque del borde del mundo (siempre cargado)
var _world_initialized := false
## Sendero del borde norte del hub al crossroads. Arranca cerrado: lo tapan
## los árboles NorthTrailTrees del city_map y el NorthTrailBlocker del hub.
## Abrirlo con set_north_trail_open(true). Se guarda en PlayerSaveData.
var north_trail_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_initialize_outside_title_menu")

## Ver PartyManager: fuera del menú principal se conserva la inicialización
## automática para tests y escenas de mundo abiertas directamente.
func _initialize_outside_title_menu() -> void:
	# GUT ejecuta los unit tests dentro del proyecto, por lo que los autoloads
	# también reciben _ready(). No cargar el mundo 3D (mapas, modelos y
	# streaming) para pruebas lógicas; los tests que sí lo necesitan viven en
	# tests/integration y lo inicializan de forma explícita.
	if _is_gut_unit_test_run():
		return
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == TITLE_MENU_SCENE:
		return
	initialize_world()


func _is_gut_unit_test_run() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("-g"):
			return true
	return false

## Construye el exterior recién al entrar a una partida. El menú inicial no
## necesita la grilla, los .glb ni la decoración automática.
func initialize_world() -> void:
	if _world_initialized:
		return
	var catalog_errors := catalog.validate()
	if not catalog_errors.is_empty():
		for error_text in catalog_errors:
			push_error("ZoneCatalog: " + error_text)
		return
	_boundary = WorldBoundary.new()
	_boundary.name = "WorldBoundary"
	add_child(_boundary)
	_boundary.build(catalog)
	_boundary.set_north_trail_open(north_trail_open)
	_streaming = ZoneStreamingController.new()
	add_child(_streaming)
	_streaming.configure(catalog, func() -> bool: return _interiors.should_show_exterior())
	_streaming.zone_loaded.connect(_on_streaming_zone_loaded)
	_streaming.zone_unloaded.connect(_on_streaming_zone_unloaded)
	_interiors = InteriorTransitionController.new()
	add_child(_interiors)
	_interiors.configure(_boundary,
		func() -> Array[Node3D]: return _streaming.loaded_zone_nodes(),
		func() -> Node3D: return _streaming.zone_node(current_zone))
	navigation.configure(_boundary, func() -> bool: return _interiors.is_inside())
	_presence = ZonePresenceTracker.new()
	add_child(_presence)
	_presence.configure(_boundary, catalog, func() -> bool: return _interiors.is_inside())
	_presence.set_current_zone(_initial_zone)
	_presence.zone_detected.connect(_on_zone_detected)
	# El hub se carga de forma bloqueante: el jugador aparece ahí.
	_streaming.load_now("hub")
	_streaming.activate("hub")
	# Posicionar party en el spawn del hub
	call_deferred("_initial_spawn")
	_world_initialized = true

func is_world_initialized() -> bool:
	return _world_initialized

func _initial_spawn() -> void:
	if not _world_initialized:
		return
	PartyManager.place_at_spawn(get_zone_node("hub"))

## Abre (o vuelve a cerrar) el sendero norte: árboles y pared del hub, y el
## camino de tierra de WorldBoundary.
func set_north_trail_open(open: bool) -> void:
	north_trail_open = open
	if not _world_initialized:
		return
	_boundary.set_north_trail_open(open)
	var hub := get_zone_node("hub")
	if hub and hub.has_method("refresh_north_trail"):
		hub.refresh_north_trail()

# ── Zonas exteriores ────────────────────────────────────────────────────────

func enter_zone(zone_id: String) -> void:
	if zone_id == current_zone or not catalog.has(zone_id):
		return
	# Los unit tests pueden evaluar reglas dependientes de zona sin construir el
	# exterior. La zona inicial actúa como estado liviano hasta que se inicialice
	# el mundo real.
	if not _world_initialized:
		var previous_zone := _initial_zone
		_initial_zone = zone_id
		zone_changed.emit(previous_zone, zone_id)
		return
	_activate_zone(zone_id)

## La zona actual es la del suelo donde está parado el jugador (el mapa de
## zonas de WorldBoundary). Antes salía de triggers que se superponían.
func refresh_current_zone() -> void:
	if _world_initialized:
		_presence.check_now()


## Consulta la zona técnica bajo una posición del exterior. También la usan
## las verificaciones de mapas; no exponen la implementación de WorldBoundary.
func world_zone_at(position: Vector3) -> String:
	return _boundary.zone_at(position) if _world_initialized else ""


## Tipo de celda técnica del exterior (WALKABLE, CLEAR, etc.).
func world_cell_type_at(position: Vector3) -> int:
	return _boundary.cell_type_at(position) if _world_initialized else WorldBoundaryGrid.EMPTY


## Nodo de decoración global por nombre (AutoGround, AutoWater, etc.).
func get_world_decoration_node(node_name: String) -> Node:
	if not _world_initialized:
		return null
	return _boundary.get_node_or_null("AutoDecoration/" + node_name)


func world_decoration_tree_positions() -> Array[Vector3]:
	return _boundary.decoration_tree_positions() if _world_initialized else []


func _on_zone_detected(zone_id: String) -> void:
	if zone_id != current_zone:
		enter_zone(zone_id)


## Al cargar el hub, vuelve a aplicar el progreso mundial aunque la zona se
## hubiera descargado antes de abrir el sendero.
func _on_streaming_zone_loaded(zone_id: String) -> void:
	if zone_id == "hub":
		set_north_trail_open(north_trail_open)
	zone_loaded.emit(zone_id)


func _on_streaming_zone_unloaded(zone_id: String) -> void:
	zone_unloaded.emit(zone_id)


func _activate_zone(zone_id: String) -> void:
	var previous_zone := current_zone
	_presence.set_current_zone(zone_id)
	_streaming.activate(zone_id)
	if previous_zone != zone_id:
		zone_changed.emit(previous_zone, zone_id)

# ── Guardado ─────────────────────────────────────────────────────────────────

## Anota en la partida dónde está el jugador.
func write_to_save(save: PlayerSaveData) -> void:
	if not _world_initialized or not PartyManager.is_initialized():
		return
	save.saved_zone = current_zone
	save.saved_interior = _interiors.scene_path()
	save.world_progress.north_trail_open = north_trail_open
	save.saved_position = PartyManager.player.global_position
	save.has_saved_position = true

## Deja al jugador donde estaba al guardar: carga esa zona ya (no en segundo
## plano, así el suelo existe cuando aparece), entra al interior si estaba en
## uno y pone al grupo en su posición.
func restore_location(zone_id: String, pos: Vector3, interior_path := "") -> void:
	if not _world_initialized:
		return
	if not catalog.has(zone_id):
		zone_id = "hub"
	_leave_interior_silently()
	# Esa zona y sus vecinas ya, así no aparece sin suelo cerca de un borde.
	_streaming.load_neighborhood_now(zone_id)
	_set_current_zone(zone_id)
	if interior_path != "" and ResourceLoader.exists(interior_path):
		enter_interior(interior_path)
		# Después de que el interior ponga al grupo en su spawn.
		PartyManager.call_deferred("place_at", pos)
	else:
		PartyManager.place_at(pos)

## Partida nueva: al inicio del hub.
func reset_to_start() -> void:
	if not _world_initialized:
		return
	_leave_interior_silently()
	set_north_trail_open(false)
	_streaming.load_now("hub")
	_set_current_zone("hub")
	PartyManager.place_at_spawn(get_zone_node("hub"))

func _set_current_zone(zone_id: String) -> void:
	_activate_zone(zone_id)

func _leave_interior_silently() -> void:
	_interiors.leave_silently()

func get_current_zone_node() -> Node3D:
	return _streaming.zone_node(current_zone) if _world_initialized else null


func get_zone_node(zone_id: String) -> Node3D:
	return _streaming.zone_node(zone_id) if _world_initialized else null


func has_loaded_zone(zone_id: String) -> bool:
	return _streaming.has_loaded_zone(zone_id) if _world_initialized else false


func get_loaded_zone_ids() -> Array[String]:
	return _streaming.loaded_zone_ids() if _world_initialized else []


func get_loaded_zone_nodes() -> Array[Node3D]:
	return _streaming.loaded_zone_nodes() if _world_initialized else []

## Bioma de una zona (o null si no tiene asignado / no está cargada).
func get_biome(zone_id: String) -> BiomeData:
	var zone := get_zone_node(zone_id) as ZoneBase
	return zone.biome if zone else null

## Bioma de la zona donde está parado el jugador ahora mismo.
func get_current_biome() -> BiomeData:
	return get_biome(current_zone)


## Geometría del mapa técnico, delegada al mismo WorldBoundary que determina
## dónde puede caminar el jugador y a qué zona pertenece.
func get_map_bounds() -> Rect2:
	return navigation.map_bounds()


func get_map_zone_edges() -> Array[Dictionary]:
	return navigation.map_zone_edges()


func get_map_zone_centers() -> Dictionary:
	return navigation.map_zone_centers()


## Ruta por el suelo transitable del mundo exterior, usada por el Youn cuando
## recupera distancia. En interiores no hay grilla global, así que no fuerza
## una ruta que pueda atravesar su geometría propia.
func find_world_path(from: Vector3, to: Vector3) -> Array[Vector2]:
	return navigation.find_path(from, to)

# ── Interiores ──────────────────────────────────────────────────────────────

func enter_interior(scene_path: String, spawn_name := "SpawnPoint") -> void:
	_interiors.enter(scene_path, spawn_name)

func exit_interior(return_spawn := "SpawnPoint") -> void:
	_interiors.exit(return_spawn)

func set_world_visible(visible: bool) -> void:
	if _world_initialized:
		_interiors.set_world_visible(visible)
