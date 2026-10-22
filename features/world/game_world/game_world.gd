extends Node3D

const SleepOverlay    := preload("res://features/world/ui/sleep_overlay.gd")
const YounInteraction := preload("res://features/world/party/youn_interaction.gd")

@onready var menu: Control = $MenuLayer/MainMenu
@onready var pause_overlay: ColorRect = $MenuLayer/PauseOverlay
@onready var intro: IntroTutorial = $IntroLayer
@onready var world_lighting: WorldLighting = $WorldLighting

var _sleeping := false
var _sleep_start_hour := 0.0

func _ready() -> void:
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_clock_paused(false)
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
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
	YounLifeEvents.restore_pending_evolution()
	YounLifeEvents.restore_pending_reincarnation()
	menu.sleep_requested.connect(_on_sleep_requested)
	intro.start()

## El Youn del grupo es el de la partida: al cargar una en la que ya evolucionó,
## el modelo tiene que ser el del Youn actual (party.tscn trae el inicial).
func _sync_party_youn() -> void:
	var ps := GameState.player_save
	var youn := PartyManager.youn
	if ps == null or not is_instance_valid(youn) or ps.current_youn_path.is_empty():
		return
	if not ResourceLoader.exists(ps.current_youn_path):
		return
	if youn.youn_data != null and youn.youn_data.resource_path == ps.current_youn_path:
		return
	if youn.has_method("load_youn"):
		youn.load_youn(load(ps.current_youn_path) as YounData)

## Después de "Nueva partida" o "Continuar": el jugador aparece al inicio o
## donde estaba al guardar.
func _restore_saved_location() -> void:
	var loc := GameState.pending_location
	if loc.is_empty():
		return
	GameState.pending_location = {}
	if loc.get("start", false):
		ZoneManager.reset_to_start()
	else:
		ZoneManager.restore_location(loc["zone"], loc["position"], loc.get("interior", ""))

func _input(event: InputEvent) -> void:
	if Dialogue.is_busy():
		if Dialogue.handle_input(event):
			get_viewport().set_input_as_handled()
		return

	if _sleeping or intro.handle_input(event):
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
	GlobalHUD.set_clock_visible(false if showing else GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_clock_paused(showing)
	GlobalHUD.set_youns_status_visible(false if showing else GlobalHUD.has_persistent_care_ui())
	PartyManager.camera_rig.enabled = not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED
	get_tree().paused = showing

func _restore_after_combat() -> void:
	if not GameState.combat_return_pending:
		return
	var pos := GameState.combat_return_position
	PartyManager.player.global_position = pos
	PartyManager.player.velocity = Vector3.ZERO
	PartyManager.youn.global_position = pos + Vector3(1.5, 0, 1.5)
	PartyManager.youn.velocity = Vector3.ZERO
	ZoneManager.resolve_pending_world_combat_victory()
	StatsManager.add_hambre(30)  # combate ganado: esfuerzo físico
	if GameState.player_save != null and GameState.player_save.bathroom_pending_after_combat:
		GameState.player_save.bathroom_pending_after_combat = false
		StatsManager.apply_bathroom_accident()


func _exit_tree() -> void:
	PauseMenu.enabled = false

func _on_sleep_requested() -> void:
	YounLifeEvents.mark_player_slept()
	_sleep_start_hour = GameState.get_total_hours()
	_toggle_menu()
	_sleeping = true
	var overlay := SleepOverlay.new()
	overlay.tree_exiting.connect(func():
		_sleeping = false
		var sleep_duration := GameState.get_total_hours() - _sleep_start_hour
		StatsManager.add_hambre(20)
		StatsManager.on_wake_up(sleep_duration)
		if overlay.save_requested:
			GameState.save_player_save()
			GlobalHUD.show_toast(LocalizationState.t("game.saved"))
	)
	add_child(overlay)
