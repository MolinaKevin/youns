class_name DebugLogging
extends RefCounted

## Consulta opcional del log verboso. Los scripts que también corren desde
## herramientas headless no pueden asumir que los autoloads del juego existen.

static func verbose_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var settings := tree.root.get_node_or_null("DebugSettings")
	return settings != null and bool(settings.get("verbose_logging_enabled"))
