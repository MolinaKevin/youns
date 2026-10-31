extends Control

## Escena puente negra entre el menú y el exterior. Mantiene la transición
## limpia mientras se construye el mundo, sin mostrar un popup de carga.

const ScenePathsScript := preload("res://shared/scene_paths.gd")
const DebugLog := preload("res://shared/debug_logging.gd")
const GAME_WORLD := ScenePathsScript.GAME_WORLD
var _flow: AsyncFlowToken

func _ready() -> void:
	_flow = AsyncFlowToken.new(self)
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	call_deferred("_load_world")


func _load_world() -> void:
	# Deja que la pantalla se dibuje antes del trabajo pesado síncrono.
	await get_tree().process_frame
	if not _flow.is_active():
		return
	var started_at := Time.get_ticks_msec()
	var party_started_at := Time.get_ticks_msec()
	PartyManager.initialize_party()
	_log("PartyManager.initialize_party: %d ms." % (Time.get_ticks_msec() - party_started_at))
	var world_started_at := Time.get_ticks_msec()
	ZoneManager.initialize_world()
	_log("ZoneManager.initialize_world: %d ms." % (Time.get_ticks_msec() - world_started_at))
	# También deja correr el spawn diferido del hub antes de restaurar ubicación.
	await get_tree().process_frame
	if not _flow.is_active():
		return
	var preloaded_world := GameState.preloaded_game_world
	GameState.preloaded_game_world = null
	if preloaded_world != null:
		_log("Total hasta GameWorld (precargado): %d ms." % (Time.get_ticks_msec() - started_at))
		_handle_scene_change(SceneNavigator.change_packed_scene_resumed(get_tree(), preloaded_world))
	else:
		_log("Total hasta GameWorld (normal): %d ms." % (Time.get_ticks_msec() - started_at))
		_handle_scene_change(SceneNavigator.change_scene_resumed(get_tree(), GAME_WORLD))


func _handle_scene_change(result: Error) -> void:
	if result == OK:
		return
	push_error("WorldLoading: no se pudo abrir GameWorld (%s)." % result)
	GlobalHUD.set_clock_paused(false)
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
	SceneNavigator.change_scene_resumed(get_tree(), ScenePathsScript.TITLE_MENU)


func _log(message: String) -> void:
	if DebugLog.verbose_enabled():
		print("[WorldLoading] " + message)


func _exit_tree() -> void:
	if _flow != null:
		_flow.cancel()
