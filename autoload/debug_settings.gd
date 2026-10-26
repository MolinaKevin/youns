extends Node

## Opciones exclusivas de desarrollo. No son estado de la partida ni se
## guardan: una exportación release las desactiva por defecto.

var developer_tools_enabled := OS.is_debug_build()
## Logs informativos y perfiles de desarrollo. Se deja apagado incluso en
## desarrollo; warnings y errores siguen apareciendo siempre.
var verbose_logging_enabled := false


func set_developer_tools_enabled(enabled: bool) -> void:
	developer_tools_enabled = enabled


func set_verbose_logging_enabled(enabled: bool) -> void:
	verbose_logging_enabled = enabled
