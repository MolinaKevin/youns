extends Node

const PARTY_SCENE := preload("res://features/world/party/party.tscn")
const CollisionLayers := preload("res://shared/world_collision_layers.gd")
const ScenePaths := preload("res://shared/scene_paths.gd")
const TITLE_MENU_SCENE := ScenePaths.TITLE_MENU
const PLAYER_PATH := ^"Player"
const YOUN_PATH := ^"Youn"
const CAMERA_RIG_PATH := ^"CameraRig"

var player: CharacterBody3D
var youn: CharacterBody3D
var camera_rig: Node3D
var next_spawn := "SpawnPoint"
var _initialized := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_initialize_outside_title_menu")

## Los tests y las escenas de mundo abiertas directamente conservan el contrato
## histórico de tener un grupo listo. El arranque normal cae en TitleMenu y se
## mantiene liviano hasta que WorldLoading lo inicializa explícitamente.
func _initialize_outside_title_menu() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == TITLE_MENU_SCENE:
		return
	initialize_party()

## El grupo sólo existe al entrar al mundo. Mantener el autoload liviano hace
## que el menú principal no tenga que importar modelos 3D ni sus animaciones.
func initialize_party() -> void:
	if _initialized:
		return
	var party := PARTY_SCENE.instantiate()
	add_child(party)
	var members := resolve_party_members(party)
	if members.is_empty():
		push_error("PartyManager: party.tscn debe tener Player (CharacterBody3D), Youn (CharacterBody3D) y CameraRig (Node3D).")
		party.queue_free()
		return
	player = members["player"]
	youn = members["youn"]
	camera_rig = members["camera_rig"]
	# Los actores caminan normalmente sobre suelo y obstáculos. El Youn cambia
	# temporalmente a sólo suelo cuando necesita recuperar distancia.
	player.collision_mask = CollisionLayers.ACTOR_WORLD_MASK
	youn.collision_mask = CollisionLayers.ACTOR_WORLD_MASK
	# Mantiene las capas actuales para que las Areas del mundo sigan detectando
	# al jugador, pero ambos CharacterBody3D se ignoran entre sí y no pueden
	# bloquearse al caminar.
	player.add_collision_exception_with(youn)
	youn.add_collision_exception_with(player)
	_initialized = true

## Resuelve el contrato estructural de party.tscn sin asumir que sus nodos
## existen. Se mantiene separado para poder validarlo sin instanciar el mundo.
static func resolve_party_members(party: Node) -> Dictionary:
	if party == null:
		return {}
	var party_player := party.get_node_or_null(PLAYER_PATH) as CharacterBody3D
	var party_youn := party.get_node_or_null(YOUN_PATH) as CharacterBody3D
	var party_camera_rig := party.get_node_or_null(CAMERA_RIG_PATH) as Node3D
	if party_player == null or party_youn == null or party_camera_rig == null:
		return {}
	return {
		"player": party_player,
		"youn": party_youn,
		"camera_rig": party_camera_rig,
	}

func is_initialized() -> bool:
	return _initialized

func place_at_spawn(scene: Node) -> void:
	if not _initialized:
		return
	var spawn := scene.get_node_or_null(next_spawn)
	next_spawn = "SpawnPoint"
	if not spawn:
		return
	var pos := (spawn as Node3D).global_position
	player.global_position = pos
	player.velocity = Vector3.ZERO
	youn.global_position = pos + Vector3(1.5, 0, 1.5)
	youn.velocity = Vector3.ZERO

## Pone al grupo en una posición (el Youn al lado del jugador).
func place_at(pos: Vector3) -> void:
	if not _initialized:
		return
	player.global_position = pos
	player.velocity = Vector3.ZERO
	youn.global_position = pos + Vector3(1.5, 0, 1.5)
	youn.velocity = Vector3.ZERO

func set_party_visible(visible: bool) -> void:
	for child in get_children():
		if child is Node3D:
			(child as Node3D).visible = visible
	if is_instance_valid(player):
		player.set_physics_process(visible)
	if is_instance_valid(youn):
		youn.set_physics_process(visible)
	if is_instance_valid(camera_rig):
		camera_rig.enabled = visible

## Congela a los dos actores del grupo para cutscenes/menús/overlays: en vez de
## que cada llamador toque `player`/`youn` directo (set_physics_process,
## velocity), pasa por acá. Zera la velocidad para no arrastrar impulso
## residual cuando se descongela.
func freeze_actors() -> void:
	if is_instance_valid(player):
		player.set_physics_process(false)
		player.velocity = Vector3.ZERO
	if is_instance_valid(youn):
		youn.set_physics_process(false)
		youn.velocity = Vector3.ZERO

func unfreeze_actors() -> void:
	if is_instance_valid(player):
		player.set_physics_process(true)
	if is_instance_valid(youn):
		youn.set_physics_process(true)

## Apaga/prende la cámara del grupo. Separado de freeze_actors() porque hay
## llamadores que sólo necesitan cortar la cámara (p. ej. un menú con el mundo
## de fondo quieto) sin tocar la física de los actores.
func freeze_camera() -> void:
	if is_instance_valid(camera_rig):
		camera_rig.enabled = false

func unfreeze_camera() -> void:
	if is_instance_valid(camera_rig):
		camera_rig.enabled = true
