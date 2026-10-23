class_name UiReturnContext
extends RefCounted

## Escena a la que debe volver una pantalla abierta desde otra escena. Es un
## valor de un solo uso para que un cierre posterior no repita la navegación.

var scene_path := ""


func set_return(path: String) -> void:
	scene_path = path


func has_return() -> bool:
	return not scene_path.is_empty()


func take_scene_path() -> String:
	var result := scene_path
	scene_path = ""
	return result


func clear() -> void:
	scene_path = ""
