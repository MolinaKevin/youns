class_name ModalScreenHudPort
extends RefCounted

## Estado de HUD que una pantalla modal puede ocultar y restaurar.

func set_clock_visible(_visible: bool) -> void: pass
func clock_visible() -> bool: return false
func set_clock_paused(_paused: bool) -> void: pass
func clock_paused() -> bool: return false
func set_youns_status_visible(_visible: bool) -> void: pass
func youns_status_visible() -> bool: return false


class Runtime extends ModalScreenHudPort:
	var _set_clock_visible: Callable
	var _clock_visible: Callable
	var _set_clock_paused: Callable
	var _clock_paused: Callable
	var _set_status_visible: Callable
	var _status_visible: Callable

	func _init(
		set_clock_visible_callback: Callable,
		clock_visible_callback: Callable,
		set_clock_paused_callback: Callable,
		clock_paused_callback: Callable,
		set_status_visible_callback: Callable,
		status_visible_callback: Callable
	) -> void:
		_set_clock_visible = set_clock_visible_callback
		_clock_visible = clock_visible_callback
		_set_clock_paused = set_clock_paused_callback
		_clock_paused = clock_paused_callback
		_set_status_visible = set_status_visible_callback
		_status_visible = status_visible_callback

	func set_clock_visible(visible: bool) -> void: _set_clock_visible.call(visible)
	func clock_visible() -> bool: return _clock_visible.call()
	func set_clock_paused(paused: bool) -> void: _set_clock_paused.call(paused)
	func clock_paused() -> bool: return _clock_paused.call()
	func set_youns_status_visible(visible: bool) -> void: _set_status_visible.call(visible)
	func youns_status_visible() -> bool: return _status_visible.call()
