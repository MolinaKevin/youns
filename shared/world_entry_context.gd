class_name WorldEntryContext
extends RefCounted

## Destino de la próxima entrada al mundo exterior. Es efímero y se consume una
## sola vez desde game_world; no es el estado persistente de la posición.

var pending := false
var starts_new_game := false
var zone_id := ""
var position := Vector3.ZERO
var interior_path := ""


func request_start() -> void:
	pending = true
	starts_new_game = true
	zone_id = ""
	position = Vector3.ZERO
	interior_path = ""


func request_restore(zone: String, world_position: Vector3, interior: String = "") -> void:
	pending = true
	starts_new_game = false
	zone_id = zone
	position = world_position
	interior_path = interior


func take() -> WorldEntryContext:
	var result := WorldEntryContext.new()
	result.pending = pending
	result.starts_new_game = starts_new_game
	result.zone_id = zone_id
	result.position = position
	result.interior_path = interior_path
	clear()
	return result


func clear() -> void:
	pending = false
	starts_new_game = false
	zone_id = ""
	position = Vector3.ZERO
	interior_path = ""
