extends Node

const PARTY_SCENE := preload("res://features/world/party/party.tscn")
const CollisionLayers := preload("res://shared/world_collision_layers.gd")
const TITLE_MENU_SCENE := "res://features/menus/main_menu/title_menu.tscn"

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
	player = party.get_node("Player")
	youn   = party.get_node("Youn")
	camera_rig = party.get_node("CameraRig")
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
