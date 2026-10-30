extends Control

## Escena puente negra entre el menú y el exterior. Mantiene la transición
## limpia mientras se construye el mundo, sin mostrar un popup de carga.

const ScenePathsScript := preload("res://shared/scene_paths.gd")
const GAME_WORLD := ScenePathsScript.GAME_WORLD

func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	call_deferred("_load_world")


func _load_world() -> void:
	# Deja que la pantalla se dibuje antes del trabajo pesado síncrono.
	await get_tree().process_frame
	var started_at := Time.get_ticks_msec()
	var party_started_at := Time.get_ticks_msec()
	PartyManager.initialize_party()
	print("[WorldLoading] PartyManager.initialize_party: %d ms." % (Time.get_ticks_msec() - party_started_at))
	var world_started_at := Time.get_ticks_msec()
	ZoneManager.initialize_world()
	print("[WorldLoading] ZoneManager.initialize_world: %d ms." % (Time.get_ticks_msec() - world_started_at))
	# También deja correr el spawn diferido del hub antes de restaurar ubicación.
	await get_tree().process_frame
	var preloaded_world := GameState.preloaded_game_world
	GameState.preloaded_game_world = null
	if preloaded_world != null:
		print("[WorldLoading] Total hasta GameWorld (precargado): %d ms." % (Time.get_ticks_msec() - started_at))
		get_tree().change_scene_to_packed(preloaded_world)
	else:
		print("[WorldLoading] Total hasta GameWorld (normal): %d ms." % (Time.get_ticks_msec() - started_at))
		get_tree().change_scene_to_file(GAME_WORLD)
