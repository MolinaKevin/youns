extends SceneTree

## Base común de los bakers (world_boundary, world_decoration, ...): aislar
## los autoloads antes de construir el mundo offline, y reparentar un
## sub-árbol para poder empaquetarlo como escena.

func _disable_autoloads() -> void:
	for autoload in root.get_children():
		autoload.process_mode = Node.PROCESS_MODE_DISABLED


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


## Error fatal del baker: loguea, libera los nodos temporales que ya se
## instanciaron y sale con error. Antes cada baker repetía push_error+free+
## quit(1) a mano en cada punto de falla.
func _fail(message: String, nodes_to_free: Array = []) -> void:
	push_error(message)
	for node in nodes_to_free:
		if node != null:
			node.free()
	quit(1)
