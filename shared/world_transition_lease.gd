class_name WorldTransitionLease
extends RefCounted

## Toma el control temporal del mundo y repone el estado que encontró. Los
## flags permiten reutilizarlo en popups, cinemáticas y pantallas sin imponer
## una política visual única.

var _hud: Variant
var _party: Variant
var _clock_was_paused := false
var _clock_was_visible := true
var _status_was_visible := true
var _tree_was_paused := false
var _tree: SceneTree
var _mouse_mode := Input.MOUSE_MODE_CAPTURED
var _player: Variant
var _youn: Variant
var _camera: Variant
var _player_physics_was_enabled := false
var _youn_physics_was_enabled := false
var _camera_was_enabled := false
var _freeze_actors := true
var _freeze_camera := true
var _pause_tree := false
var _released := false


func _init(hud: Variant, party: Variant, options: Dictionary = {}) -> void:
	_hud = hud
	_party = party
	_freeze_actors = options.get("freeze_actors", true)
	_freeze_camera = options.get("freeze_camera", true)
	_pause_tree = options.get("pause_tree", false)
	_clock_was_paused = _hud.clock_paused()
	_clock_was_visible = _hud.clock_visible()
	_status_was_visible = _hud.youns_status_visible()
	_mouse_mode = Input.mouse_mode
	_tree = Engine.get_main_loop() as SceneTree
	_tree_was_paused = _tree.paused if _tree else false
	_snapshot_party_state()

	_hud.set_clock_paused(true)
	if options.get("hide_clock", false):
		_hud.set_clock_visible(false)
	if options.get("hide_status", false):
		_hud.set_youns_status_visible(false)
	if _freeze_actors:
		_party.freeze_actors()
	if _freeze_camera:
		_party.freeze_camera()
	if options.get("show_mouse", true):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _pause_tree and _tree:
		_tree.paused = true


func release() -> void:
	if _released:
		return
	_released = true
	if _tree and _pause_tree:
		_tree.paused = _tree_was_paused
	_restore_party_state()
	if is_instance_valid(_hud):
		_hud.set_clock_paused(_clock_was_paused)
		_hud.set_clock_visible(_clock_was_visible)
		_hud.set_youns_status_visible(_status_was_visible)
	Input.mouse_mode = _mouse_mode


func _snapshot_party_state() -> void:
	if not is_instance_valid(_party):
		return
	_player = _party.player
	_youn = _party.youn
	_camera = _party.camera_rig
	_player_physics_was_enabled = _player.is_physics_processing() if is_instance_valid(_player) else false
	_youn_physics_was_enabled = _youn.is_physics_processing() if is_instance_valid(_youn) else false
	_camera_was_enabled = _camera.enabled if is_instance_valid(_camera) else false


func _restore_party_state() -> void:
	if _freeze_actors:
		if is_instance_valid(_player):
			_player.set_physics_process(_player_physics_was_enabled)
		if is_instance_valid(_youn):
			_youn.set_physics_process(_youn_physics_was_enabled)
	if _freeze_camera and is_instance_valid(_camera):
		_camera.enabled = _camera_was_enabled
