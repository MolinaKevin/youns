class_name CareSessionContext
extends RefCounted

## Datos y notificaciones de la sesión que necesitan los servicios de cuidado.
##
## CareStatsService y EmotionService no conocen autoloads: StatsManager arma
## este contexto en juego, y tests u otros modos pueden proveer otro origen.

var _get_player_save: Callable
var _get_youn_data: Callable
var _get_total_hours: Callable
var _notify_youns_status_changed: Callable


func _init(get_player_save: Callable, get_youn_data: Callable, get_total_hours: Callable, notify_youns_status_changed: Callable) -> void:
	_get_player_save = get_player_save
	_get_youn_data = get_youn_data
	_get_total_hours = get_total_hours
	_notify_youns_status_changed = notify_youns_status_changed


func player_save() -> PlayerSaveData:
	return _get_player_save.call() as PlayerSaveData


func youn_data() -> YounData:
	return _get_youn_data.call() as YounData


func total_hours() -> float:
	return float(_get_total_hours.call())


func notify_youns_status_changed() -> void:
	_notify_youns_status_changed.call()
