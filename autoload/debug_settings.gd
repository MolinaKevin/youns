extends Node

## Opciones exclusivas de desarrollo. No son estado de la partida ni se
## guardan: una exportación release las desactiva por defecto.

var developer_tools_enabled := OS.is_debug_build()


func set_developer_tools_enabled(enabled: bool) -> void:
	developer_tools_enabled = enabled
