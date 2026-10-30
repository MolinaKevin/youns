class_name SaveFeatureBridge
extends RefCounted

## Integra SaveService con los sistemas que restauran o serializan estado de
## gameplay. SaveService queda limitado a datos, migraciones y almacenamiento.

var _restore: Callable
var _write: Callable


func _init(restore_callback: Callable, write_callback: Callable) -> void:
	_restore = restore_callback
	_write = write_callback


func restore(save: PlayerSaveData) -> void:
	_restore.call(save)


func write(save: PlayerSaveData) -> void:
	_write.call(save)
