class_name ZoneStreamingController
extends Node

## Carga las zonas exteriores que rodean a la zona activa. ZoneManager mantiene
## la API pública; este nodo concentra ResourceLoader, instanciación y descarte.

const AutoDecorationScript := preload("res://features/world/zones/auto_decoration.gd")
const CollisionLayers := preload("res://shared/world_collision_layers.gd")
const DebugLogging := preload("res://shared/debug_logging.gd")

signal zone_loaded(zone_id: String)
signal zone_unloaded(zone_id: String)

var _loaded: Dictionary = {}   # id -> ZoneBase
var _loading: Dictionary = {}  # id -> ruta pedida a ResourceLoader
var _catalog: ZoneCatalog
var _show_exterior: Callable
var _active_zone := ""


func configure(catalog: ZoneCatalog, show_exterior: Callable) -> void:
	_catalog = catalog
	_show_exterior = show_exterior


func load_now(zone_id: String) -> void:
	if _loaded.has(zone_id):
		return
	var definition := _catalog.definition(zone_id)
	if definition == null:
		push_error("ZoneStreamingController: zona inexistente '%s'." % zone_id)
		return
	_loading.erase(zone_id)
	_log_streaming("Cargando", zone_id)
	var scene := load(definition.scene_path) as PackedScene
	if scene == null:
		push_error("ZoneStreamingController: no se pudo cargar '%s'." % definition.scene_path)
		return
	_add_zone(zone_id, scene)


func load_neighborhood_now(zone_id: String) -> void:
	for id in zones_to_keep(zone_id):
		load_now(id)


func activate(zone_id: String) -> void:
	if not _catalog.has(zone_id):
		push_error("ZoneStreamingController: zona inexistente '%s'." % zone_id)
		return
	_active_zone = zone_id
	_request_zones(zones_to_keep(zone_id))
	for id in _loaded.keys().duplicate():
		if id not in zones_to_keep(zone_id):
			_unload_zone(id)


func zones_to_keep(zone_id: String) -> Array[String]:
	var definition := _catalog.definition(zone_id)
	var result: Array[String] = []
	if definition == null:
		return result
	result.append(zone_id)
	result.append_array(definition.connections)
	return result


func zone_node(zone_id: String) -> Node3D:
	return _loaded.get(zone_id) as Node3D


func has_loaded_zone(zone_id: String) -> bool:
	return _loaded.has(zone_id)


func loaded_zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _loaded:
		ids.append(id)
	return ids


func loaded_zone_nodes() -> Array[Node3D]:
	var zones: Array[Node3D] = []
	for zone in _loaded.values():
		zones.append(zone as Node3D)
	return zones


func _process(_delta: float) -> void:
	if _loading.is_empty() or _active_zone.is_empty():
		return
	var to_keep := zones_to_keep(_active_zone)
	for id in _loading.keys().duplicate():
		var path: String = _loading[id]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_loading.erase(id)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("ZoneStreamingController: no se pudo cargar la zona '%s' (%s)" % [id, path])
			continue
		var scene: PackedScene = ResourceLoader.load_threaded_get(path)
		# El jugador pudo cambiar de zona durante la carga.
		if id in to_keep and not _loaded.has(id):
			_add_zone(id, scene)


func _request_zones(ids: Array[String]) -> void:
	for id in ids:
		if _loaded.has(id) or _loading.has(id):
			continue
		var definition := _catalog.definition(id)
		if definition == null:
			push_error("ZoneStreamingController: zona inexistente '%s'." % id)
			continue
		var path := definition.scene_path
		_log_streaming("Cargando", id)
		ResourceLoader.load_threaded_request(path)
		_loading[id] = path


func _add_zone(id: String, scene: PackedScene) -> void:
	var inst := scene.instantiate() as ZoneBase
	if inst == null:
		push_error("ZoneStreamingController: '%s' no instancia una ZoneBase." % id)
		return
	CollisionLayers.configure_ground_colliders(inst)
	CollisionLayers.configure_camera_terrain_colliders(inst)
	AutoDecorationScript.remove_guides(inst)
	inst.zone_id = id
	inst.position = _catalog.definition(id).offset
	inst.visible = _show_exterior.call()
	get_parent().add_child(inst)
	_loaded[id] = inst
	_log_streaming("Cargado", id)
	zone_loaded.emit(id)


func _unload_zone(id: String) -> void:
	var zone := _loaded.get(id) as Node
	if zone == null:
		return
	zone.queue_free()
	_loaded.erase(id)
	_log_streaming("Descargado", id)
	zone_unloaded.emit(id)


func _log_streaming(action: String, zone_id: String) -> void:
	if not DebugLogging.verbose_enabled():
		return
	var loaded_ids := loaded_zone_ids()
	loaded_ids.sort()
	print("[ZoneStreaming] %s: %s | Cargadas: [%s]" % [action, zone_id, ", ".join(loaded_ids)])
