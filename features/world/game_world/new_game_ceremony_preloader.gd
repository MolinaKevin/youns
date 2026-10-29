class_name NewGameCeremonyPreloader
extends RefCounted

## Aísla la precarga de escenas del diálogo y la presentación de la ceremonia.

var world_started := false
var hub_started := false

func request(world_path: String, hub_path: String) -> void:
	world_started = ResourceLoader.load_threaded_request(world_path, "PackedScene", true) == OK
	hub_started = ResourceLoader.load_threaded_request(hub_path, "PackedScene", true) == OK

func collect(world_path: String, hub_path: String) -> void:
	if world_started:
		var status := ResourceLoader.load_threaded_get_status(world_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			GameState.preloaded_game_world = ResourceLoader.load_threaded_get(world_path) as PackedScene
	if hub_started and ResourceLoader.load_threaded_get_status(hub_path) == ResourceLoader.THREAD_LOAD_LOADED:
		var hub_scene := ResourceLoader.load_threaded_get(hub_path) as PackedScene
		if hub_scene != null:
			GameState.preloaded_zone_scenes[hub_path] = hub_scene
