extends Node3D

@onready var menu: Control = $MenuLayer/MainMenu

func _ready() -> void:
	ZoneManager.set_world_visible(true)
	PartyManager.set_party_visible(true)
	PartyManager.camera_rig.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_environment()
	_setup_screen_fx()
	_restore_after_combat()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and ZoneManager._interior == null:
		_toggle_menu()

func _toggle_menu() -> void:
	var showing := not menu.visible
	menu.visible = showing
	PartyManager.camera_rig.enabled = not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.85)
	env.fog_enabled = true
	env.fog_density = 0.015
	env.fog_light_color = Color(0.55, 0.65, 0.78)
	env.fog_light_energy = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.6
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
