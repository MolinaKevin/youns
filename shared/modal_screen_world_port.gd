class_name ModalScreenWorldPort
extends RefCounted

## Visibilidad del mundo exterior durante una pantalla modal.

func set_world_visible(_visible: bool) -> void: pass


class Runtime extends ModalScreenWorldPort:
	var _set_visible: Callable

	func _init(set_visible_callback: Callable) -> void:
		_set_visible = set_visible_callback

	func set_world_visible(visible: bool) -> void: _set_visible.call(visible)
