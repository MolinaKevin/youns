extends GutTest

# Convención de pisos: cada mapa trae su colisión de suelo en el .glb
# (<Mapa>Floor-colonly, *-col de rampas/suelos) con la forma de lo caminable.
# Ninguna zona usa una caja "Floor" suelta en su .tscn (se salían del mapa y
# tapaban cañones). Excepción: el hub, cuyo city_map no trae piso completo.

const CollisionLayers := preload("res://shared/world_collision_layers.gd")


func _instance(zone_id: String) -> Node3D:
	var scene: PackedScene = load(ZoneManager.catalog.definition(zone_id).scene_path)
	return scene.instantiate() as Node3D


func test_ninguna_zona_usa_una_caja_de_piso() -> void:
	for zone_id in ZoneManager.catalog.ids():
		if zone_id == "hub":
			continue   # el hub conserva su caja: el city_map no tiene piso completo
		var zone := _instance(zone_id)
		assert_null(zone.get_node_or_null("Floor"), "%s todavía tiene una caja Floor" % zone_id)
		zone.free()


func test_cada_mapa_trae_su_piso() -> void:
	for zone_id in ZoneManager.catalog.ids():
		if zone_id == "gym":
			continue   # el gym tiene GymGround-col; se revisa aparte abajo
		var zone := _instance(zone_id)
		CollisionLayers.configure_ground_colliders(zone)
		var ground := 0
		for node in zone.find_children("*", "StaticBody3D", true, false):
			if (node as StaticBody3D).collision_layer == CollisionLayers.GROUND:
				ground += 1
		assert_gt(ground, 0, "%s no tiene colisión de suelo" % zone_id)
		zone.free()


func test_el_gym_tiene_su_suelo() -> void:
	var zone := _instance("gym")
	CollisionLayers.configure_ground_colliders(zone)
	var ground := 0
	for node in zone.find_children("*", "StaticBody3D", true, false):
		if (node as StaticBody3D).collision_layer == CollisionLayers.GROUND:
			ground += 1
	assert_gt(ground, 0)
	zone.free()


func test_los_puntos_de_aparicion_caen_sobre_suelo() -> void:
	for zone_id in ZoneManager.catalog.ids():
		var zone := _instance(zone_id)
		var spawn := zone.get_node_or_null("SpawnPoint") as Node3D
		if spawn != null:
			var pos: Vector3 = ZoneManager.catalog.definition(zone_id).offset + spawn.position
			var cell: int = ZoneManager._boundary.cell_type_at(pos)
			assert_true(cell == WorldBoundaryGrid.WALKABLE or cell == WorldBoundaryGrid.RESERVED,
				"el SpawnPoint de %s (%s) no está sobre suelo caminable" % [zone_id, pos])
		zone.free()


# Entre dos praderas de un mapa no tiene que quedar una franja vacía: la
# grilla le pondría una pared invisible en el medio del paso.
func test_los_pasos_entre_praderas_no_tienen_pared() -> void:
	var pasos := [
		Vector3(-177.5, 0, -248.5),   # pinar: subida -> claro
		Vector3(-164.5, 0, -278.5),   # pinar: claro -> paso
		Vector3(-14.5, 0, -211.5),    # lomas: subida desde la pradera norte
		Vector3(57.5, 0, -277.5),     # lomas -> mirador
		Vector3(78.5, 0, -243.5),     # mirador: subida -> claro
	]
	for p in pasos:
		assert_eq(ZoneManager._boundary.cell_type_at(p), WorldBoundaryGrid.WALKABLE, "pared en %s" % p)
