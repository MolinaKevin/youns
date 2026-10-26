extends Control

## Escena puente entre el menú y el exterior. Se muestra un frame antes de
## construir el mundo para que el usuario vea que la partida está cargando.

const ScenePaths := preload("res://shared/scene_paths.gd")
const GAME_WORLD := ScenePaths.GAME_WORLD

@onready var status_label: Label = $Center/Panel/Margin/VBox/Status


func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	call_deferred("_load_world")


func _load_world() -> void:
	# Deja que la pantalla se dibuje antes del trabajo pesado síncrono.
	await get_tree().process_frame
	status_label.text = LocalizationState.t("world.loading.prepare_companion")
	PartyManager.initialize_party()
	status_label.text = LocalizationState.t("world.loading.build_world")
	ZoneManager.initialize_world()
	# También deja correr el spawn diferido del hub antes de restaurar ubicación.
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_WORLD)
