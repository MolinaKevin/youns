class_name CombatLog
extends RefCounted

## Punto único para los mensajes del registro de combate. Las acciones emiten
## claves y argumentos, nunca textos ya formateados: así el idioma se resuelve
## al momento de escribir el mensaje.

static func text(key: String, args: Array = []) -> String:
	return LocalizationState.t(key, args)

static func emit_requested(log_requested: Signal, key: String, args: Array = []) -> void:
	log_requested.emit(text(key, args))
