class_name SceneNavigator
extends RefCounted

## Punto único para abrir una pantalla standalone y volver a la escena que la
## invocó. Evita que cada UI tenga que recordar cómo se consume ui_return.

static func open_from_current(tree: SceneTree, target_scene: String) -> Error:
	var current := tree.current_scene
	if is_instance_valid(current) and not current.scene_file_path.is_empty():
		GameState.ui_return.set_return(current.scene_file_path)
	return change_scene_resumed(tree, target_scene)


static func return_to_origin(tree: SceneTree, fallback: String = ScenePaths.GAME_WORLD) -> Error:
	var target := fallback
	if GameState.ui_return.has_return():
		target = GameState.ui_return.take_scene_path()
	return change_scene_resumed(tree, target)


static func return_to_session_origin(tree: SceneTree) -> Error:
	var fallback := ScenePaths.GAME_WORLD if GameState.save_service.session_active else ScenePaths.TITLE_MENU
	return return_to_origin(tree, fallback)


## Toda transición a otra escena libera la pausa del árbol anterior. La nueva
## escena decide su propio estado modal en _ready().
static func change_scene_resumed(tree: SceneTree, target_scene: String) -> Error:
	tree.paused = false
	QuickMenu.cancel_pending_action()
	return tree.change_scene_to_file(target_scene)


## Variante para una escena ya precargada. Mantiene el mismo contrato que las
## transiciones por ruta: ninguna pausa del origen puede filtrarse al destino.
static func change_packed_scene_resumed(tree: SceneTree, target_scene: PackedScene) -> Error:
	tree.paused = false
	QuickMenu.cancel_pending_action()
	return tree.change_scene_to_packed(target_scene)


## Reinicio pensado para escenas abiertas directamente desde el editor.
static func reload_current_scene_resumed(tree: SceneTree) -> Error:
	tree.paused = false
	QuickMenu.cancel_pending_action()
	return tree.reload_current_scene()
