extends Node

# Grafo de zonas: id -> { scene, offset, connections }
var ZONES := {
	"hub": {
		"scene":       "res://features/world/zones/zone_hub.tscn",
		"offset":      Vector3(0, 0, 0),
		"connections": ["crossroads", "right"]
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
var _interior: Node3D = null   # escena interior activa (lab, dungeon, etc.)

func _ready() -> void:
	_load_zone("hub")
	for conn in ZONES["hub"]["connections"]:
		_load_zone(conn)
	# Posicionar party en el spawn del hub
	call_deferred("_initial_spawn")

func _initial_spawn() -> void:
	PartyManager.place_at_spawn(_loaded["hub"])

# ── Zonas exteriores ────────────────────────────────────────────────────────

func enter_zone(zone_id: String) -> void:
	if zone_id == current_zone:
		return
	current_zone = zone_id
	var to_keep: Array = [zone_id] + ZONES[zone_id]["connections"]
	for id in to_keep:
		_load_zone(id)
	for id in _loaded.keys().duplicate():
		if id not in to_keep:
			_unload_zone(id)

func _load_zone(id: String) -> void:
	if _loaded.has(id):
		return
	var inst: Node3D = load(ZONES[id]["scene"]).instantiate()
	inst.position = ZONES[id]["offset"]
	add_child(inst)
	_loaded[id] = inst

func _unload_zone(id: String) -> void:
	if not _loaded.has(id):
		return
	_loaded[id].queue_free()
	_loaded.erase(id)

# ── Interiores ──────────────────────────────────────────────────────────────

func enter_interior(scene_path: String, spawn_name := "SpawnPoint") -> void:
	for inst in _loaded.values():
		inst.hide()
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
	PartyManager.next_spawn = return_spawn
	PartyManager.place_at_spawn(_loaded[current_zone])

func set_world_visible(visible: bool) -> void:
	for inst in _loaded.values():
		inst.visible = visible
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
