class_name SceneNavigator
extends RefCounted

## Punto único para abrir una pantalla standalone y volver a la escena que la
## invocó. Evita que cada UI tenga que recordar cómo se consume ui_return.

static func open_from_current(tree: SceneTree, target_scene: String) -> Error:
	var current := tree.current_scene
	if is_instance_valid(current) and not current.scene_file_path.is_empty():
		GameState.ui_return.set_return(current.scene_file_path)
	return tree.change_scene_to_file(target_scene)


static func return_to_origin(tree: SceneTree, fallback: String = ScenePaths.GAME_WORLD) -> Error:
	var target := fallback
	if GameState.ui_return.has_return():
		target = GameState.ui_return.take_scene_path()
	return tree.change_scene_to_file(target)


static func return_to_session_origin(tree: SceneTree) -> Error:
	var fallback := ScenePaths.GAME_WORLD if GameState.save_service.session_active else ScenePaths.TITLE_MENU
	return return_to_origin(tree, fallback)
