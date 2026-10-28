class_name ModalScreenPartyPort
extends RefCounted

## Visibilidad del party durante una pantalla modal.

func set_party_visible(_visible: bool) -> void: pass


class Runtime extends ModalScreenPartyPort:
	var _set_visible: Callable

	func _init(set_visible_callback: Callable) -> void:
		_set_visible = set_visible_callback

	func set_party_visible(visible: bool) -> void: _set_visible.call(visible)
