class_name AsyncFlowToken
extends RefCounted

## Token pequeño para invalidar continuaciones después de un await. Si se
## asocia a un Node, se cancela al salir del árbol.

var _cancelled := false


func _init(owner: Node = null) -> void:
	if is_instance_valid(owner):
		owner.tree_exiting.connect(cancel, CONNECT_ONE_SHOT)


func cancel() -> void:
	_cancelled = true


func is_active() -> bool:
	return not _cancelled
