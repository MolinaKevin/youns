extends Node3D

const SleepOverlay    := preload("res://features/world/ui/sleep_overlay.gd")
const YounInteraction := preload("res://features/world/party/youn_interaction.gd")
const NewWorldWelcomeScript := preload("res://features/world/game_world/new_world_welcome.gd")
const TypedResourceLoaderScript := preload("res://shared/typed_resource_loader.gd")

@onready var menu: Control = $MenuLayer/MainMenu
@onready var pause_overlay: ColorRect = $MenuLayer/PauseOverlay
@onready var intro: IntroTutorial = $IntroLayer
@onready var world_lighting: WorldLighting = $WorldLighting

var _sleeping := false
var _sleep_start_hour := 0.0
var _menu_modal: ModalScreenContext
var _session := WorldSessionCoordinator.new()

func _ready() -> void:
	_menu_modal = ModalScreenContext.new(ModalScreenHost.from_runtime())
	# Permite abrir esta escena sola desde el editor; el flujo normal llega desde
	# WorldLoading y ya tiene ambos autoloads inicializados.
	PartyManager.initialize_party()
	ZoneManager.initialize_world()
	GlobalHUD.sync_overworld_ui_visibility()
	GlobalHUD.set_clock_paused(false)
	PauseMenu.enabled = false
	ZoneManager.set_world_visible(true)
	PartyManager.set_party_visible(true)
	PartyManager.camera_rig.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Ps1ScreenFx.attach(self)
	_sync_party_youn()
	_restore_saved_location()
	_restore_after_combat()
	YounLifeEvents.world_lighting = world_lighting
	_connect_life_event_signals()
	YounLifeEvents.restore_pending_evolution()
	YounLifeEvents.restore_pending_reincarnation()
	menu.sleep_requested.connect(_on_sleep_requested)
	if GameState.new_game_ceremony_completed:
		_start_new_world_welcome()
	else:
		intro.start()


func _start_new_world_welcome() -> void:
	intro.visible = false
	var welcome := NewWorldWelcomeScript.new()
	welcome.finished.connect(func() -> void:
		intro.tutorial_finished.connect(welcome.restore_gameplay_camera, CONNECT_ONE_SHOT)
		intro.start())
	add_child(welcome)
	welcome.start()

## El Youn del grupo es el de la partida: al cargar una en la que ya evolucionó,
## el modelo tiene que ser el del Youn actual (party.tscn trae el inicial).
func _sync_party_youn() -> void:
	var ps := PlayerSessionAccess.save()
	var youn := PartyManager.youn
	if ps == null or not is_instance_valid(youn) or ps.current_youn_path.is_empty():
		return
	var data := TypedResourceLoaderScript.youn(ps.current_youn_path)
	if data == null:
		return
	if youn.youn_data != null and youn.youn_data.resource_path == ps.current_youn_path:
		return
	if youn.has_method("load_youn"):
		youn.load_youn(data)

## Después de "Nueva partida" o "Continuar": el jugador aparece al inicio o
## donde estaba al guardar.
func _restore_saved_location() -> void:
	var entry := GameState.world_entry.take()
	if not entry.pending:
		return
	if entry.starts_new_game:
		ZoneManager.reset_to_start()
	else:
		ZoneManager.restore_location(entry.zone_id, entry.position, entry.interior_path)

func _input(event: InputEvent) -> void:
	if Dialogue.is_busy():
		Dialogue.handle_input(event)
		# Mientras hay diálogo, ninguna otra capa (G, pausa, mapa, etc.)
		# debe recibir teclas aunque el diálogo no use ese evento.
		get_viewport().set_input_as_handled()
		return
	if _sleeping or intro.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	# El menú rápido (G) usa Enter para elegir, que también abre este menú.
	if QuickMenu.visible or YounInteraction.running:
		return
	if InputPresses.is_menu_pressed(event) and not intro.is_active():
		if menu.visible or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_toggle_menu()
	elif InputPresses.is_cancel_pressed(event) and menu.visible:
		_toggle_menu()

func _toggle_menu() -> void:
	var showing := not menu.visible
	menu.visible = showing
	pause_overlay.visible = showing
	if showing:
		_menu_modal.enter_overlay(true, true, true)
		PartyManager.freeze_camera()
	else:
		_menu_modal.exit_overlay()
		GlobalHUD.sync_overworld_ui_visibility()
		PartyManager.unfreeze_camera()

func _restore_after_combat() -> void:
	_session.restore_after_combat(GameState.world_combat, PartyManager.player, PartyManager.youn,
		get_tree(), StatsManager.services.care(), PlayerSessionAccess.save())


func _exit_tree() -> void:
	_disconnect_life_event_signals()
	PauseMenu.enabled = false


func _connect_life_event_signals() -> void:
	if not StatsManager.evolution_triggered.is_connected(YounLifeEvents.present_evolution):
		StatsManager.evolution_triggered.connect(YounLifeEvents.present_evolution)
	if not StatsManager.reincarnation_triggered.is_connected(YounLifeEvents.present_reincarnation):
		StatsManager.reincarnation_triggered.connect(YounLifeEvents.present_reincarnation)


func _disconnect_life_event_signals() -> void:
	if StatsManager.evolution_triggered.is_connected(YounLifeEvents.present_evolution):
		StatsManager.evolution_triggered.disconnect(YounLifeEvents.present_evolution)
	if StatsManager.reincarnation_triggered.is_connected(YounLifeEvents.present_reincarnation):
		StatsManager.reincarnation_triggered.disconnect(YounLifeEvents.present_reincarnation)


func _on_sleep_requested() -> void:
	YounLifeEvents.mark_player_slept()
	_sleep_start_hour = GameState.get_total_hours()
	_toggle_menu()
	_sleeping = true
	var overlay := SleepOverlay.new()
	overlay.tree_exiting.connect(func():
		_sleeping = false
		_session.finish_sleep(_sleep_start_hour, GameState.get_total_hours(), StatsManager.services.care(), StatsManager.services.emotions())
		if overlay.save_requested:
			GameState.save_player_save_and_notify()
	)
	add_child(overlay)
