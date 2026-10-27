class_name SaveFeatureBridge
extends RefCounted

## Integra SaveService con los sistemas que restauran o serializan estado de
## gameplay. SaveService queda limitado a datos, migraciones y almacenamiento.

var _restore: Callable
var _write: Callable


func _init(restore: Callable, write: Callable) -> void:
	_restore = restore
	_write = write


func restore(save: PlayerSaveData) -> void:
	_restore.call(save)


func write(save: PlayerSaveData) -> void:
	_write.call(save)
