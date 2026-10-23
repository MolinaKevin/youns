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


func test_el_hub_sigue_del_otro_lado_del_rio() -> void:
	assert_eq(_zone_at(-34, 0), "hub", "franja al pie de la montaña")
	assert_eq(_zone_at(-40, -60), "hub", "la franja sigue al norte, junto al río")
	assert_eq(_zone_at(-33.5, 10), "hub", "el cruce del río")
	assert_eq(_zone_at(-90, -40), "hub", "la montaña")


func _cell(x: float, z: float) -> int:
	return ZoneManager._boundary.cell_type_at(Vector3(x, 0, z))


func test_la_montana_no_se_camina_pero_su_frente_si() -> void:
	assert_eq(_cell(-34, 0), WorldBoundaryGrid.WALKABLE, "franja al pie de la montaña")
	assert_eq(_cell(-55, 0), WorldBoundaryGrid.CLEAR, "la ladera ya no se camina")
	assert_eq(_cell(-92, -45), WorldBoundaryGrid.CLEAR, "pico norte")
	assert_eq(_cell(-90, 20), WorldBoundaryGrid.CLEAR, "pico sur")
	assert_eq(_cell(-33.5, 10), WorldBoundaryGrid.WALKABLE, "el cruce del río")
	assert_eq(_cell(-28.5, 0), WorldBoundaryGrid.CLEAR, "el agua del río, dentro del hub")
	assert_eq(_cell(-34, -60), WorldBoundaryGrid.CLEAR, "el río sigue al norte del hub")
	assert_eq(_cell(-30.5, 68), WorldBoundaryGrid.CLEAR, "el pozón de la cascada del hub")
	assert_eq(_cell(-60, 88), WorldBoundaryGrid.CLEAR, "el macizo de las cascadas")


func test_la_pradera_norte_conecta_hub_pradera_y_left() -> void:
	assert_eq(_zone_at(6.5, -90), "crossroads", "pasillo que sigue al sendero norte del hub")
	assert_eq(_cell(6.5, -90), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(86, -79), WorldBoundaryGrid.WALKABLE, "pasillo hasta Hub2Left de la pradera")
	assert_eq(_cell(-80, -158), WorldBoundaryGrid.WALKABLE, "pasillo hasta left")
	assert_eq(_cell(-40, -110), WorldBoundaryGrid.EMPTY, "entre los claros hay bosque")


func test_el_sendero_norte_arranca_cerrado_y_se_puede_abrir() -> void:
	assert_false(ZoneManager.north_trail_open, "arranca cerrado")
	var hub := ZoneManager.get_zone_node("hub")
	assert_not_null(hub)
	var blocker: CollisionShape3D = hub.get_node("NorthTrailBlocker/Col")
	var trees: Node3D = hub.get_node("CityMap").find_child("NorthTrailTrees", true, false)
	assert_false(blocker.disabled)
	assert_true(trees.visible)
	ZoneManager.set_north_trail_open(true)
	assert_true(blocker.disabled, "abierto: sin pared")
	assert_false(trees.visible, "abierto: sin árboles")
	ZoneManager.set_north_trail_open(false)
	assert_false(blocker.disabled)
	assert_eq(_cell(6.5, -50), WorldBoundaryGrid.WALKABLE, "el sendero sigue en la grilla, lo cierran los árboles y la pared")
	assert_eq(_cell(-10, -50), WorldBoundaryGrid.CLEAR, "el bosque del city_map no lleva árboles generados")


func test_la_pradera_oeste_llega_hasta_la_montana() -> void:
	assert_eq(_zone_at(-104, -80), "left", "claro de la Ladera")
	assert_eq(_cell(-104, -80), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(-104, -62), WorldBoundaryGrid.CLEAR, "justo al sur empieza la montaña")
	assert_eq(_cell(-76, -155), WorldBoundaryGrid.WALKABLE, "entrada desde el crossroads")
	assert_true("hub" in ZoneManager.catalog.definition("left").connections, "desde left se ve la montaña")
	assert_eq(_cell(-104, -66), WorldBoundaryGrid.CLEAR, "la Ladera se mete bajo la ladera: ahí ya es montaña")


func test_el_bosque_de_las_praderas_no_se_camina() -> void:
	assert_ne(_cell(-20, -112), WorldBoundaryGrid.WALKABLE, "el bosque del crossroads no se camina")
	assert_eq(_cell(0, -150), WorldBoundaryGrid.WALKABLE, "el claro sigue caminable")


func test_la_meseta_tiene_precipicio_y_se_entra_por_el_puente() -> void:
	assert_eq(_zone_at(-290, -150), "cliffs", "centro de la meseta")
	assert_eq(_cell(-290, -150), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(-290, -205), WorldBoundaryGrid.CLEAR, "el cañón al norte de la meseta")
	assert_eq(_cell(-345, -150), WorldBoundaryGrid.CLEAR, "el cañón al oeste")
	assert_eq(_cell(-238, -150), WorldBoundaryGrid.WALKABLE, "el puente natural cruza el cañón")
	assert_eq(_cell(-200, -151), WorldBoundaryGrid.WALKABLE, "sendero hasta el Valle")
	assert_true("cliffs" in ZoneManager.catalog.definition("left").connections)


func test_el_codo_baja_detras_de_la_montana_con_precipicio_afuera() -> void:
	assert_eq(_zone_at(-145, 0), "elbow", "brazo norte, al oeste de la montaña")
	assert_eq(_cell(-145, 0), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(-90, 120), WorldBoundaryGrid.WALKABLE, "brazo este, al sur de las cascadas")
	assert_eq(_cell(-179, 40), WorldBoundaryGrid.CLEAR, "cañón al oeste")
	assert_eq(_cell(-100, 146), WorldBoundaryGrid.CLEAR, "cañón al sur")
	assert_eq(_cell(-150, -118), WorldBoundaryGrid.WALKABLE, "el pedacito del codo pegado al Valle")
	assert_true("elbow" in ZoneManager.catalog.definition("left").connections)
	assert_eq(_cell(-179, -60), WorldBoundaryGrid.CLEAR, "la roca baja hasta el río del cañón")
	assert_eq(_cell(-145, -60), WorldBoundaryGrid.CLEAR, "la roca cruza el pasto del codo")
	assert_eq(_cell(-122, -60), WorldBoundaryGrid.CLEAR, "y llega hasta la montaña")
	assert_eq(_cell(-145, -30), WorldBoundaryGrid.WALKABLE, "del otro lado de la roca sigue el codo")
	assert_eq(_cell(-145, -92), WorldBoundaryGrid.WALKABLE, "antes de la roca, el pedazo pegado al Valle")
	assert_eq(_cell(-104, -80), WorldBoundaryGrid.WALKABLE, "la roca no tapa la Ladera de la pradera oeste")
	assert_ne(_cell(-180, -85), WorldBoundaryGrid.WALKABLE, "antes de la roca ya no hay cañón: es bosque")
	assert_eq(_zone_at(-38, 110), "elbow", "claro de la cueva, detrás del gym")
	assert_eq(_cell(-38, 110), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(-55, 110), WorldBoundaryGrid.WALKABLE, "el claro de la cueva sigue del pasto del codo")
	assert_ne(_cell(-38, 120), WorldBoundaryGrid.WALKABLE, "alrededor, bosque")


func test_el_rio_del_codo_sigue_por_la_ribera_y_el_recodo() -> void:
	assert_eq(_cell(-30, 146.5), WorldBoundaryGrid.CLEAR, "el cañón del codo llega hondo hasta su borde este")
	assert_eq(_zone_at(23, 137), "riverside", "la caleta detrás del gym, al nivel del río")
	assert_eq(_cell(23, 137), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(23, 149), WorldBoundaryGrid.CLEAR, "el río al costado de la caleta")
	assert_ne(_cell(23, 122), WorldBoundaryGrid.WALKABLE, "arriba de la pared es bosque")
	assert_eq(_cell(22, 110), WorldBoundaryGrid.RESERVED, "el bosque del gym termina antes de la ribera")
	assert_eq(_zone_at(100, 125), "bend", "brazo oeste del recodo")
	assert_eq(_cell(100, 125), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(133, 82), WorldBoundaryGrid.WALKABLE, "se une con la salida de abajo de la pradera")
	assert_eq(_cell(100, 146.5), WorldBoundaryGrid.CLEAR, "cañón al sur del recodo")
	assert_eq(_cell(160, 150), WorldBoundaryGrid.CLEAR, "el cañón dobla al norte por el este")
	assert_ne(_cell(66, 125), WorldBoundaryGrid.WALKABLE, "la punta oeste la cierran árboles")
	assert_true("bend" in ZoneManager.catalog.definition("right").connections)
	assert_eq(_cell(162, 118), WorldBoundaryGrid.WALKABLE, "el rellano de la bajada sale del pasto")
	assert_eq(_cell(164.5, 90), WorldBoundaryGrid.WALKABLE, "el primer tramo baja por la pared del brazo este")
	assert_eq(_cell(167, 67), WorldBoundaryGrid.WALKABLE, "el descanso del zigzag")
	assert_eq(_cell(169, 100), WorldBoundaryGrid.WALKABLE, "el segundo tramo vuelve hasta la playa")
	assert_eq(_cell(162, 90), WorldBoundaryGrid.CLEAR, "entre el pasto y la rampa hay pared (no se salta)")
	assert_eq(_cell(172, 100), WorldBoundaryGrid.WALKABLE, "la rampa llega a la playa")
	assert_eq(_cell(185, 100), WorldBoundaryGrid.CLEAR, "el río, del otro lado de la playa")
	assert_eq(_zone_at(172, 100), "bend")


func test_la_playa_sigue_al_final_del_recodo() -> void:
	assert_eq(_zone_at(230, 0), "beach", "la playa ancha")
	assert_eq(_cell(230, 0), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(175, 61.5), WorldBoundaryGrid.WALKABLE, "se pasa de la playa del recodo a la playa")
	assert_true("beach" in ZoneManager.catalog.definition("bend").connections)


func test_las_praderas_del_norte_se_conectan_y_terminan_en_precipicio() -> void:
	assert_eq(_zone_at(-180, -266), "pinewood", "claro del Pinar")
	assert_eq(_cell(-180, -266), WorldBoundaryGrid.WALKABLE)
	assert_eq(_cell(-186, -212), WorldBoundaryGrid.WALKABLE, "se sube al Pinar desde el Bosquecito")
	assert_eq(_cell(-94, -306), WorldBoundaryGrid.WALKABLE, "del Pinar a las Lomas")
	assert_eq(_zone_at(-10, -272), "hills", "claro de las Lomas")
	assert_eq(_cell(-18, -220), WorldBoundaryGrid.WALKABLE, "se sube a las Lomas desde el claro norte del crossroads")
	assert_eq(_cell(32, -282), WorldBoundaryGrid.WALKABLE, "de las Lomas al Mirador")
	assert_eq(_zone_at(102, -276), "overlook", "claro del Mirador")
	assert_eq(_cell(48, -198), WorldBoundaryGrid.WALKABLE, "se sube al Mirador desde el claro noreste")
	assert_ne(_cell(-100, -345), WorldBoundaryGrid.WALKABLE, "más allá del borde norte, el precipicio")
	assert_ne(_cell(150, -275), WorldBoundaryGrid.WALKABLE, "el Mirador termina en precipicio al este")
	assert_ne(_cell(-210, -280), WorldBoundaryGrid.WALKABLE, "el Pinar termina en precipicio al oeste")
	assert_true("pinewood" in ZoneManager.catalog.definition("left").connections)
	assert_true("hills" in ZoneManager.catalog.definition("crossroads").connections)
	assert_true("overlook" in ZoneManager.catalog.definition("crossroads").connections)


func test_fuera_de_todo_no_hay_zona() -> void:
	assert_eq(_zone_at(-400, 400), "")


func test_la_zona_actual_sigue_al_jugador() -> void:
	PartyManager.place_at(Vector3(10, 1, 73))
	ZoneManager._update_current_zone()
	assert_eq(ZoneManager.current_zone, "gym")
	PartyManager.place_at(Vector3(0, 1, 0))
	ZoneManager._update_current_zone()
	assert_eq(ZoneManager.current_zone, "hub")


func test_entrar_a_una_zona_emite_el_cambio() -> void:
	var changes: Array[Array] = []
	var on_change := func(previous_zone: String, current_zone: String) -> void:
		changes.append([previous_zone, current_zone])
	ZoneManager.zone_changed.connect(on_change)
	var destination := "gym" if ZoneManager.current_zone != "gym" else "hub"
	var origin := ZoneManager.current_zone
	ZoneManager.enter_zone(destination)
	ZoneManager.zone_changed.disconnect(on_change)
	assert_eq(changes, [[origin, destination]])
