class_name ZonePresenceTracker
extends Node

## Observa el suelo de WorldBoundary a intervalos y avisa al coordinador cuando
## el jugador cruzó a otra zona. No carga ni descarga escenas.

signal zone_detected(zone_id: String)

const CHECK_INTERVAL := 0.2

var _boundary: Node3D
var _catalog: ZoneCatalog
var _is_inside: Callable
var _player_position: Callable
var _timer := 0.0
var current_zone := "hub"


## `player_position` es opcional: sin uno propio (el caso real, ver
## zone_manager.gd), cae en PartyManager.player. Se resuelve acá, una sola
## vez, para que check_now() no tenga que bifurcar en cada chequeo.
func configure(boundary: Node3D, catalog: ZoneCatalog, is_inside: Callable, player_position: Callable = Callable()) -> void:
	_boundary = boundary
	_catalog = catalog
	_is_inside = is_inside
	_player_position = player_position if player_position.is_valid() else _default_player_position


func set_current_zone(zone_id: String) -> void:
	current_zone = zone_id


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK_INTERVAL
		check_now()


func check_now() -> void:
	if _is_inside.call():
		return
	var position: Variant = _player_position.call()
	if position == null:
		return
	var zone_id: String = _boundary.zone_at(position)
	if not zone_id.is_empty() and _catalog.has(zone_id) and zone_id != current_zone:
		zone_detected.emit(zone_id)


static func _default_player_position() -> Variant:
	if not is_instance_valid(PartyManager.player):
		return null
	return PartyManager.player.global_position
