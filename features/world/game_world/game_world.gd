extends Node3D

const SleepOverlay := preload("res://features/world/ui/sleep_overlay.gd")

@onready var menu: Control = $MenuLayer/MainMenu
@onready var intro_layer: CanvasLayer = $IntroLayer
@onready var intro_title: Label = $IntroLayer/Panel/Margin/VBox/Title
@onready var intro_body: RichTextLabel = $IntroLayer/Panel/Margin/VBox/Body
@onready var intro_hint: Label = $IntroLayer/Panel/Margin/VBox/Hint

# Un keyframe por sector. Noche usa hora 20→28 (28 = 4h del día siguiente) para manejar el wrap.
# [hora, sky, fog_color, fog_density, fog_energy, ambient_color, ambient_energy, sun_color, sun_energy, fill_energy]
const LIGHTING_KF := [
	[4.0,  Color(0.72,0.48,0.28), Color(0.65,0.48,0.32), 0.022, 0.40, Color(0.52,0.38,0.22), 0.35, Color(1.00,0.70,0.40), 0.45, 0.08],  # Mañana
	[8.0,  Color(0.45,0.62,0.82), Color(0.52,0.60,0.70), 0.015, 0.60, Color(0.45,0.48,0.44), 0.55, Color(1.00,0.96,0.82), 0.85, 0.14],  # Día
	[16.0, Color(0.68,0.32,0.12), Color(0.60,0.36,0.20), 0.025, 0.42, Color(0.46,0.24,0.12), 0.38, Color(1.00,0.48,0.18), 0.55, 0.08],  # Tarde
	[20.0, Color(0.05,0.06,0.16), Color(0.07,0.09,0.20), 0.030, 0.20, Color(0.09,0.10,0.20), 0.14, Color(0.60,0.65,1.00), 0.00, 0.02],  # Noche
	[28.0, Color(0.72,0.48,0.28), Color(0.65,0.48,0.32), 0.022, 0.40, Color(0.52,0.38,0.22), 0.35, Color(1.00,0.70,0.40), 0.45, 0.08],  # Mañana (wrap)
]

var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D

const TRANSITION_DURATION := 2.0
var _period_idx: int = -1
var _transition_t: float = 1.0
var _from_kf: Array = []
var _to_kf: Array = []

const INTRO_PAGES := [
	{
		"title_key": "world.intro.page_1.title",
		"body_key": "world.intro.page_1.body"
	},
	{
		"title_key": "world.intro.page_2.title",
		"body_key": "world.intro.page_2.body"
	},
	{
		"title_key": "world.intro.page_3.title",
		"body_key": "world.intro.page_3.body"
	},
	{
		"title_key": "world.intro.page_4.title",
		"body_key": "world.intro.page_4.body"
	},
	{
		"title_key": "world.intro.page_5.title",
		"body_key": "world.intro.page_5.body"
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
	_update_lighting(GameState.time_of_day_hours, GameState.current_day)
	GameState.clock_changed.connect(_update_lighting)
	GameState.clock_changed.connect(_check_sleep_penalty)
	GameState.clock_changed.connect(_drain_cansancio)
	GameState.clock_changed.connect(_check_end_of_night)
	_setup_screen_fx()
	_restore_after_combat()
	LocalizationState.language_changed.connect(_refresh_intro_language)
	menu.sleep_requested.connect(_on_sleep_requested)
	_setup_intro()

func _input(event: InputEvent) -> void:
	if _sleeping or _handle_intro_input(event):
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
	env.fog_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world_env = WorldEnvironment.new()
	_world_env.environment = env
	add_child(_world_env)

	_sun = DirectionalLight3D.new()
	_sun.transform = Transform3D(
		Basis(Vector3(0.866, -0.354, 0.354), Vector3(0.0, 0.707, 0.707), Vector3(-0.5, -0.612, 0.612)),
		Vector3(0, 10, 0))
	_sun.shadow_enabled = true
	add_child(_sun)

	_fill = DirectionalLight3D.new()
	_fill.transform = Transform3D(
		Basis(Vector3(-0.866, -0.2, -0.46), Vector3(0.0, 0.917, -0.4), Vector3(0.5, -0.346, -0.795)),
		Vector3(0, 8, 0))
	_fill.shadow_enabled = false
	add_child(_fill)

func _get_period_idx(hour: float) -> int:
	var h := hour if hour >= 4.0 else hour + 24.0
	for i in range(LIGHTING_KF.size() - 1):
		if h >= (LIGHTING_KF[i][0] as float) and h < (LIGHTING_KF[i + 1][0] as float):
			return i
	return 0

func _update_lighting(current_hour: float, _day: int) -> void:
	if _world_env == null:
		return
	var new_idx := _get_period_idx(current_hour)
	if new_idx == _period_idx:
		return
	var is_init := _period_idx < 0
	_from_kf = LIGHTING_KF[maxi(_period_idx, 0)]
	_period_idx = new_idx
	_to_kf = LIGHTING_KF[new_idx]
	if is_init:
		_transition_t = 1.0
		_apply_kf(_to_kf)
	elif _transition_t < 1.0:
		_from_kf = _snapshot_lighting()
		_transition_t = 0.0
	else:
		_transition_t = 0.0

func _process(delta: float) -> void:
	if _transition_t >= 1.0 or _world_env == null:
		return
	_transition_t = minf(_transition_t + delta / TRANSITION_DURATION, 1.0)
	_apply_kf_lerp(_from_kf, _to_kf, _transition_t)

func _apply_kf(kf: Array) -> void:
	var env := _world_env.environment
	env.background_color     = kf[1] as Color
	env.fog_light_color      = kf[2] as Color
	env.fog_density          = kf[3] as float
	env.fog_light_energy     = kf[4] as float
	env.ambient_light_color  = kf[5] as Color
	env.ambient_light_energy = kf[6] as float
	var sun_energy: float    = kf[8] as float
	_sun.light_color    = kf[7] as Color
	_sun.light_energy   = sun_energy
	_sun.shadow_enabled = sun_energy > 0.05
	_fill.light_energy  = kf[9] as float

func _apply_kf_lerp(a: Array, b: Array, t: float) -> void:
	var env := _world_env.environment
	env.background_color     = (a[1] as Color).lerp(b[1] as Color, t)
	env.fog_light_color      = (a[2] as Color).lerp(b[2] as Color, t)
	env.fog_density          = lerpf(a[3] as float, b[3] as float, t)
	env.fog_light_energy     = lerpf(a[4] as float, b[4] as float, t)
	env.ambient_light_color  = (a[5] as Color).lerp(b[5] as Color, t)
	env.ambient_light_energy = lerpf(a[6] as float, b[6] as float, t)
	var sun_energy: float    = lerpf(a[8] as float, b[8] as float, t)
	_sun.light_color    = (a[7] as Color).lerp(b[7] as Color, t)
	_sun.light_energy   = sun_energy
	_sun.shadow_enabled = sun_energy > 0.05
	_fill.light_energy  = lerpf(a[9] as float, b[9] as float, t)

func _snapshot_lighting() -> Array:
	var env := _world_env.environment
	return [
		0.0,
		env.background_color,
		env.fog_light_color,
		env.fog_density,
		env.fog_light_energy,
		env.ambient_light_color,
		env.ambient_light_energy,
		_sun.light_color,
		_sun.light_energy,
		_fill.light_energy,
	]

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
var _sleeping := false
var _sleep_penalty_applied := false
var _last_cansancio_drain_hour := -1
var _was_in_sleep_range := false
var _slept_this_cycle := false
var _sleep_tracking_initialized := false
var _sick_sleep_count := 0

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
	intro_title.text = LocalizationState.t(page["title_key"])
	intro_body.text = LocalizationState.t(page["body_key"])
	intro_hint.text = LocalizationState.t("world.intro.hint", [_intro_index + 1, INTRO_PAGES.size()])

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
	if GameState.clock_changed.is_connected(_update_lighting):
		GameState.clock_changed.disconnect(_update_lighting)
	if GameState.clock_changed.is_connected(_check_sleep_penalty):
		GameState.clock_changed.disconnect(_check_sleep_penalty)
	if GameState.clock_changed.is_connected(_drain_cansancio):
		GameState.clock_changed.disconnect(_drain_cansancio)
	if GameState.clock_changed.is_connected(_check_end_of_night):
		GameState.clock_changed.disconnect(_check_end_of_night)
	PauseMenu.enabled = false

func _on_sleep_requested() -> void:
	_slept_this_cycle = true
	if GameState.player_save != null and GameState.player_save.enfermo:
		_sick_sleep_count += 1
		if _sick_sleep_count >= 2:
			_sick_sleep_count = 0
			GameState.set_enfermo(false)
			GameState.add_care_mistake(1)
	_toggle_menu()
	_sleeping = true
	var overlay := SleepOverlay.new()
	overlay.tree_exiting.connect(func(): _sleeping = false)
	add_child(overlay)

func _check_sleep_penalty(hour: float, _day: int) -> void:
	var youn_node = PartyManager.youn if PartyManager else null
	if not is_instance_valid(youn_node) or youn_node.youn_data == null:
		return
	var data: YounData = youn_node.youn_data
	if not _hour_in_range(hour, data.sleep_hour, data.wake_hour):
		_sleep_penalty_applied = false
		return
	if _sleep_penalty_applied:
		return
	var penalty_h := (data.sleep_hour + 1) % 24
	if _hour_in_range(hour, penalty_h, data.wake_hour):
		_sleep_penalty_applied = true
		GameState.add_care_mistake(1)

func _drain_cansancio(hour: float, _day: int) -> void:
	var current_hour := floori(hour)
	if current_hour == _last_cansancio_drain_hour:
		return
	_last_cansancio_drain_hour = current_hour
	GameState.drain_cansancio(4)

func _check_end_of_night(hour: float, _day: int) -> void:
	var youn_node = PartyManager.youn if PartyManager else null
	if not is_instance_valid(youn_node) or youn_node.youn_data == null:
		return
	var data: YounData = youn_node.youn_data
	var in_sleep := _hour_in_range(hour, data.sleep_hour, data.wake_hour)
	if not _sleep_tracking_initialized:
		_was_in_sleep_range = in_sleep
		_sleep_tracking_initialized = true
		return
	if in_sleep and not _was_in_sleep_range:
		_slept_this_cycle = false
	if not in_sleep and _was_in_sleep_range:
		if not _slept_this_cycle:
			GameState.add_salud(-30)
			if GameState.player_save != null and GameState.player_save.cansancio < 20:
				GameState.set_enfermo(true)
	_was_in_sleep_range = in_sleep

func _hour_in_range(hour: float, from_h: int, to_h: int) -> bool:
	if from_h > to_h:
		return hour >= float(from_h) or hour < float(to_h)
	return hour >= float(from_h) and hour < float(to_h)

func _refresh_intro_language(_language: String = "") -> void:
	if _intro_active:
		_show_intro_page()
