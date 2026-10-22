extends Node

const WorldBoundary := preload("res://features/world/zones/world_boundary.gd")

# Grafo de zonas: id -> { scene, offset, connections }. Las conexiones son las
# zonas vecinas que se mantienen cargadas mientras el jugador está en esa zona.
# La zona actual sale de dónde está parado el jugador (ver _update_current_zone).
var ZONES := {
	"hub": {
		"scene":       "res://features/world/zones/zone_hub.tscn",
		"offset":      Vector3(0, 0, 0),
		"connections": ["crossroads", "right", "gym"]
	},
	"gym": {
		"scene":       "res://features/world/zones/zone_gym.tscn",
		# Al sur del hub (el este es la pradera): el camino del gym
		# (GymHubConnection, z local -40) empalma con el borde sur del suelo del hub, en (10, 0, 33).
		"offset":      Vector3(10, 0, 73),
		"connections": ["hub"]
	},
	"crossroads": {
		"scene":       "res://features/world/zones/zone_crossroads.tscn",
		"offset":      Vector3(0, 0, -150),
		"connections": ["hub", "left", "right"]
	},
	"left": {
		"scene":       "res://features/world/zones/zone_left.tscn",
		"offset":      Vector3(-150, 0, -150),
		"connections": ["crossroads"]
	},
	"right": {
		"scene":       "res://features/world/zones/zone_right.tscn",
		# Ajustado para que, visto desde el laboratorio, el acceso desde el
		# hub conecte con el pasillo izquierdo de la pradera derecha.
		"offset":      Vector3(36.0, 0, 38.0),
		"connections": ["hub", "crossroads"]
	},
}

var current_zone := "hub"
var _loaded: Dictionary = {}   # id -> Node3D
var _loading: Dictionary = {}  # id -> ruta de escena pedida a ResourceLoader
var _interior: Node3D = null   # escena interior activa (lab, dungeon, etc.)
var _world_visible := true
## Cada cuánto se mira en qué zona está parado el jugador.
const ZONE_CHECK_INTERVAL := 0.2
var _zone_check_timer := 0.0
var _boundary: Node3D = null   # paredes y bosque del borde del mundo (siempre cargado)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_boundary = WorldBoundary.new()
	_boundary.name = "WorldBoundary"
	add_child(_boundary)
	_boundary.build(ZONES)
	# El hub se carga de forma bloqueante: el jugador aparece ahí.
	_add_zone("hub", load(ZONES["hub"]["scene"]))
	_request_zones(_zones_to_keep("hub"))
	# Posicionar party en el spawn del hub
	call_deferred("_initial_spawn")

func _initial_spawn() -> void:
	PartyManager.place_at_spawn(_loaded["hub"])

# ── Zonas exteriores ────────────────────────────────────────────────────────

func enter_zone(zone_id: String) -> void:
	if zone_id == current_zone:
		return
	current_zone = zone_id
	var to_keep := _zones_to_keep(zone_id)
	_request_zones(to_keep)
	for id in _loaded.keys().duplicate():
		if id not in to_keep:
			_unload_zone(id)

func _zones_to_keep(zone_id: String) -> Array:
	return [zone_id] + ZONES[zone_id]["connections"]

# Pide en segundo plano las zonas que falten; _process las agrega al terminar.
func _request_zones(ids: Array) -> void:
	for id in ids:
		if _loaded.has(id) or _loading.has(id):
			continue
		var path: String = ZONES[id]["scene"]
		ResourceLoader.load_threaded_request(path)
		_loading[id] = path

func _process(delta: float) -> void:
	_zone_check_timer -= delta
	if _zone_check_timer <= 0.0:
		_zone_check_timer = ZONE_CHECK_INTERVAL
		_update_current_zone()
	if _loading.is_empty():
		return
	var to_keep := _zones_to_keep(current_zone)
	for id in _loading.keys().duplicate():
		var path: String = _loading[id]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_loading.erase(id)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("ZoneManager: no se pudo cargar la zona '%s' (%s)" % [id, path])
			continue
		var scene: PackedScene = ResourceLoader.load_threaded_get(path)
		# El jugador pudo haberse movido mientras cargaba (o ya se cargó en el momento).
		if id in to_keep and not _loaded.has(id):
			_add_zone(id, scene)

## La zona actual es la del suelo donde está parado el jugador (el mapa de
## zonas de WorldBoundary). Antes salía de triggers que se superponían.
func _update_current_zone() -> void:
	if _interior != null or not is_instance_valid(PartyManager.player):
		return
	var zone_id: String = _boundary.zone_at(PartyManager.player.global_position)
	if zone_id != "" and ZONES.has(zone_id) and zone_id != current_zone:
		enter_zone(zone_id)

func _add_zone(id: String, scene: PackedScene) -> void:
	var inst: ZoneBase = scene.instantiate()
	inst.zone_id = id
	inst.position = ZONES[id]["offset"]
	inst.visible = _world_visible and _interior == null
	add_child(inst)
	_loaded[id] = inst

func _unload_zone(id: String) -> void:
	if not _loaded.has(id):
		return
	_loaded[id].queue_free()
	_loaded.erase(id)

# ── Guardado ─────────────────────────────────────────────────────────────────

## Anota en la partida dónde está el jugador.
func write_to_save(save: PlayerSaveData) -> void:
	save.saved_zone = current_zone
	save.saved_interior = _interior.scene_file_path if _interior else ""
	save.saved_position = PartyManager.player.global_position
	save.has_saved_position = true

## Deja al jugador donde estaba al guardar: carga esa zona ya (no en segundo
## plano, así el suelo existe cuando aparece), entra al interior si estaba en
## uno y pone al grupo en su posición.
func restore_location(zone_id: String, pos: Vector3, interior_path := "") -> void:
	if not ZONES.has(zone_id):
		zone_id = "hub"
	_leave_interior_silently()
	# Esa zona y sus vecinas ya, así no aparece sin suelo cerca de un borde.
	for id in _zones_to_keep(zone_id):
		if not _loaded.has(id):
			_loading.erase(id)
			_add_zone(id, load(ZONES[id]["scene"]))
	_set_current_zone(zone_id)
	if interior_path != "" and ResourceLoader.exists(interior_path):
		enter_interior(interior_path)
		# Después de que el interior ponga al grupo en su spawn.
		PartyManager.call_deferred("place_at", pos)
	else:
		PartyManager.place_at(pos)

## Partida nueva: al inicio del hub.
func reset_to_start() -> void:
	_leave_interior_silently()
	if not _loaded.has("hub"):
		_loading.erase("hub")
		_add_zone("hub", load(ZONES["hub"]["scene"]))
	_set_current_zone("hub")
	PartyManager.place_at_spawn(_loaded["hub"])

func _set_current_zone(zone_id: String) -> void:
	current_zone = zone_id
	var to_keep := _zones_to_keep(zone_id)
	_request_zones(to_keep)
	for id in _loaded.keys().duplicate():
		if id not in to_keep:
			_unload_zone(id)

func _leave_interior_silently() -> void:
	if _interior:
		_interior.queue_free()
		_interior = null
	for inst in _loaded.values():
		inst.visible = _world_visible
	_boundary.visible = _world_visible

func get_current_zone_node() -> Node3D:
	return _loaded.get(current_zone)

## Bioma de una zona (o null si no tiene asignado / no está cargada).
func get_biome(zone_id: String) -> BiomeData:
	var zone: ZoneBase = _loaded.get(zone_id)
	return zone.biome if zone else null

## Bioma de la zona donde está parado el jugador ahora mismo.
func get_current_biome() -> BiomeData:
	return get_biome(current_zone)


## Geometría del mapa técnico, delegada al mismo WorldBoundary que determina
## dónde puede caminar el jugador y a qué zona pertenece.
func get_map_bounds() -> Rect2:
	return _boundary.get_map_bounds() if _boundary else Rect2()


func get_map_zone_edges() -> Array[Dictionary]:
	return _boundary.get_map_zone_edges() if _boundary else []


func get_map_zone_centers() -> Dictionary:
	return _boundary.get_map_zone_centers() if _boundary else {}

# ── Interiores ──────────────────────────────────────────────────────────────

func enter_interior(scene_path: String, spawn_name := "SpawnPoint") -> void:
	for inst in _loaded.values():
		inst.hide()
	_boundary.hide()
	var interior: Node3D = load(scene_path).instantiate()
	interior.name = "_Interior"
	add_child(interior)
	_interior = interior
	# Dejar un frame para que el interior esté en el árbol antes de spawnear
	call_deferred("_spawn_in_interior", spawn_name)

func _spawn_in_interior(spawn_name: String) -> void:
	PartyManager.next_spawn = spawn_name
	PartyManager.place_at_spawn(_interior)

func exit_interior(return_spawn := "SpawnPoint") -> void:
	if _interior:
		_interior.queue_free()
		_interior = null
	for inst in _loaded.values():
		inst.show()
	_boundary.show()
	PartyManager.next_spawn = return_spawn
	PartyManager.place_at_spawn(_loaded[current_zone])

func set_world_visible(visible: bool) -> void:
	_world_visible = visible
	for inst in _loaded.values():
		inst.visible = visible
	_boundary.visible = visible and _interior == null
	if _interior:
		_interior.visible = visible

func resolve_pending_world_combat_victory() -> void:
	if not GameState.combat_return_pending or GameState.combat_world_enemy_id == "":
		return
	for enemy in get_tree().get_nodes_in_group("world_enemy"):
		if enemy.has_method("handle_player_victory") and enemy.get("world_enemy_id") == GameState.combat_world_enemy_id:
			enemy.handle_player_victory(GameState.combat_return_position)
			break
	GameState.combat_return_pending = false
	GameState.combat_world_enemy_id = ""
