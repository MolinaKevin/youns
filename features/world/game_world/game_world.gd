extends Node3D

@onready var menu: Control = $MenuLayer/MainMenu
@onready var intro_layer: CanvasLayer = $IntroLayer
@onready var intro_title: Label = $IntroLayer/Panel/Margin/VBox/Title
@onready var intro_body: RichTextLabel = $IntroLayer/Panel/Margin/VBox/Body
@onready var intro_hint: Label = $IntroLayer/Panel/Margin/VBox/Hint

const INTRO_PAGES := [
	{
		"title": "Bienvenido",
		"body": "[center]Esto es un demo corto youns.[/center]"
	},
	{
		"title": "Moverse",
		"body": "Usa [b]WASD[/b] para moverte.\nMueve la camara con el mouse.\nCon Tab abris menu"
	},
	{
		"title": "Enemigos",
		"body": "Si un enemigo te toca, te intercepta y entras en combate.\n El sistema de combate es una suerte de deck builder tactico."
	},
	{
		"title": "LAB",
		"body": "Otra mecanica importante del juego va a ser una mecanica incremental.\nPodemos acceder a esto hablando con el npc en el lab."
	}
]

func _ready() -> void:
	GameState.set_clock_visible(GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(false)
	GameState.set_youns_status_visible(GameState.has_persistent_care_ui())
	PauseMenu.enabled = false
	ZoneManager.set_world_visible(true)
	PartyManager.set_party_visible(true)
	PartyManager.camera_rig.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_environment()
	_setup_screen_fx()
	_restore_after_combat()
	_setup_intro()

func _input(event: InputEvent) -> void:
	if _handle_intro_input(event):
		return
	if _is_menu_pressed(event) and not intro_layer.visible:
		_toggle_menu()
	elif _is_cancel_pressed(event) and menu.visible:
		_toggle_menu()

func _toggle_menu() -> void:
	var showing := not menu.visible
	menu.visible = showing
	GameState.set_clock_visible(false if showing else GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(showing)
	GameState.set_youns_status_visible(false if showing else GameState.has_persistent_care_ui())
	PartyManager.camera_rig.enabled = not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.28, 0.36, 0.5)
	env.fog_enabled = true
	env.fog_density = 0.02
	env.fog_light_color = Color(0.38, 0.45, 0.55)
	env.fog_light_energy = 0.55
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.25, 0.32)
	env.ambient_light_energy = 0.32
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _setup_screen_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://features/world/world_map/ps1_screen.gdshader")
	mat.set_shader_parameter("pixel_size", 2.0)
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

func _restore_after_combat() -> void:
	if not GameState.combat_return_pending:
		return
	var pos := GameState.combat_return_position
	PartyManager.player.global_position = pos
	PartyManager.player.velocity = Vector3.ZERO
	PartyManager.youn.global_position = pos + Vector3(1.5, 0, 1.5)
	PartyManager.youn.velocity = Vector3.ZERO
	ZoneManager.resolve_pending_world_combat_victory()

var _intro_index := 0
var _intro_active := false

func _setup_intro() -> void:
	if GameState.combat_return_pending or GameState.world_intro_seen:
		intro_layer.visible = false
		return
	_intro_active = true
	_intro_index = 0
	intro_layer.visible = true
	GameState.set_clock_visible(false)
	GameState.set_clock_paused(true)
	GameState.set_youns_status_visible(false)
	PartyManager.camera_rig.enabled = false
	PartyManager.player.set_physics_process(false)
	PartyManager.youn.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_intro_page()

func _show_intro_page() -> void:
	var page: Dictionary = INTRO_PAGES[_intro_index]
	intro_title.text = page["title"]
	intro_body.text = page["body"]
	intro_hint.text = "Enter o Espacio para continuar  (%d/%d)" % [_intro_index + 1, INTRO_PAGES.size()]

func _handle_intro_input(event: InputEvent) -> bool:
	if not _intro_active:
		return false
	if event.is_action_pressed("ui_accept") or (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE
	):
		_intro_index += 1
		if _intro_index >= INTRO_PAGES.size():
			_close_intro()
		else:
			_show_intro_page()
		return true
	return true

func _close_intro() -> void:
	_intro_active = false
	GameState.world_intro_seen = true
	intro_layer.visible = false
	GameState.set_clock_visible(GameState.has_persistent_clock_ui())
	GameState.set_clock_paused(false)
	GameState.set_youns_status_visible(GameState.has_persistent_care_ui())
	PartyManager.camera_rig.enabled = true
	PartyManager.player.set_physics_process(true)
	PartyManager.youn.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_cancel_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _is_menu_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("menu_toggle"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _exit_tree() -> void:
	PauseMenu.enabled = false
