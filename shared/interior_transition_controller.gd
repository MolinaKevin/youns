class_name InteriorTransitionController
extends Node

## Maneja la escena efímera de un interior sin mezclarla con la carga de zonas
## exteriores. Es hijo de ZoneManager: los interiores se agregan a ese mismo
## árbol para conservar las rutas y grupos que ya espera el juego.

var _boundary: Node3D
var _loaded_zone_nodes: Callable
var _current_zone_node: Callable
var _interior: Node3D
var _world_visible := true


func configure(boundary: Node3D, loaded_zone_nodes: Callable, current_zone_node: Callable) -> void:
	_boundary = boundary
	_loaded_zone_nodes = loaded_zone_nodes
	_current_zone_node = current_zone_node


func is_inside() -> bool:
	return is_instance_valid(_interior)


func scene_path() -> String:
	return _interior.scene_file_path if is_inside() else ""


func should_show_exterior() -> bool:
	return _world_visible and not is_inside()


func enter(interior_scene_path: String, spawn_name := "SpawnPoint") -> void:
	var packed_scene := load(interior_scene_path) as PackedScene
	if packed_scene == null:
		push_error("InteriorTransitionController: no se pudo cargar '%s'." % interior_scene_path)
		return
	leave_silently()
	for zone in _loaded_zone_nodes.call():
		zone.hide()
	_boundary.hide()
	_interior = packed_scene.instantiate() as Node3D
	_interior.name = "_Interior"
	get_parent().add_child(_interior)
	_interior.visible = _world_visible
	# Dejar un frame para que el interior esté en el árbol antes de spawnear.
	call_deferred("_spawn_in_interior", spawn_name)


func exit(return_spawn := "SpawnPoint") -> void:
	leave_silently()
	PartyManager.next_spawn = return_spawn
	var zone := _current_zone_node.call() as Node3D
	if zone != null:
		PartyManager.place_at_spawn(zone)


func leave_silently() -> void:
	if is_inside():
		_interior.queue_free()
	_interior = null
	for zone in _loaded_zone_nodes.call():
		zone.visible = _world_visible
	_boundary.visible = _world_visible


func set_world_visible(visible: bool) -> void:
	_world_visible = visible
	for zone in _loaded_zone_nodes.call():
		zone.visible = should_show_exterior()
	_boundary.visible = should_show_exterior()
	if is_inside():
		_interior.visible = visible


func _spawn_in_interior(spawn_name: String) -> void:
	if not is_inside():
		return
	PartyManager.next_spawn = spawn_name
	PartyManager.place_at_spawn(_interior)
