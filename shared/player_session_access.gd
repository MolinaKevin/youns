class_name PlayerSessionAccess
extends RefCounted

## Lectura centralizada de la partida activa para UI y coordinadores. Mantiene
## GameState como composición de runtime, no como dependencia de cada widget.

static func save() -> PlayerSaveData:
	return GameState.save_service.player_save if GameState != null and GameState.save_service != null else null

static func has_active_save() -> bool:
	return save() != null
