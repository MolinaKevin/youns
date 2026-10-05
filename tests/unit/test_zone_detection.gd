extends GutTest

# La zona actual sale de dónde está parado el jugador (mapa de zonas de
# WorldBoundary), no de triggers que se superponen.

var _zone := ""
var _pos := Vector3.ZERO


func before_each() -> void:
	_zone = ZoneManager.current_zone
	_pos = PartyManager.player.global_position


func after_each() -> void:
	PartyManager.place_at(_pos)
	ZoneManager.enter_zone(_zone)


func _zone_at(x: float, z: float) -> String:
	return ZoneManager._boundary.zone_at(Vector3(x, 1, z))


func test_cada_zona_segun_su_suelo() -> void:
	assert_eq(_zone_at(0, 0), "hub")
	assert_eq(_zone_at(6.5, -50), "hub", "el sendero norte es del hub")
	assert_eq(_zone_at(0, -150), "crossroads")
	assert_eq(_zone_at(-150, -150), "left")
	assert_eq(_zone_at(10, 73), "gym")
	assert_eq(_zone_at(10, 40), "gym", "el camino del gym")
	assert_eq(_zone_at(100, 0), "right", "la pradera")


func test_parado_en_el_hub_no_es_la_pradera() -> void:
	# Antes el trigger de la pradera cubría el hub.
	assert_eq(_zone_at(20, 10), "hub")
	assert_eq(_zone_at(-10, 20), "hub")


func test_fuera_de_todo_no_hay_zona() -> void:
	assert_eq(_zone_at(-400, 400), "")


func test_la_zona_actual_sigue_al_jugador() -> void:
	PartyManager.place_at(Vector3(10, 1, 73))
	ZoneManager._update_current_zone()
	assert_eq(ZoneManager.current_zone, "gym")
	PartyManager.place_at(Vector3(0, 1, 0))
	ZoneManager._update_current_zone()
	assert_eq(ZoneManager.current_zone, "hub")
