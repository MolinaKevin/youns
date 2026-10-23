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


func configure(boundary: Node3D, catalog: ZoneCatalog, is_inside: Callable, player_position: Callable = Callable()) -> void:
	_boundary = boundary
	_catalog = catalog
	_is_inside = is_inside
	_player_position = player_position


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
	var position: Vector3
	if _player_position.is_valid():
		position = _player_position.call()
	elif is_instance_valid(PartyManager.player):
		position = PartyManager.player.global_position
	else:
		return
	var zone_id: String = _boundary.zone_at(position)
	if not zone_id.is_empty() and _catalog.has(zone_id) and zone_id != current_zone:
		zone_detected.emit(zone_id)
