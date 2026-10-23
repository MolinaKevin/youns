extends GutTest

const ZoneCatalog := preload("res://data/zones/zone_catalog.gd")
const ZoneStreamingController := preload("res://shared/zone_streaming_controller.gd")
const ZonePresenceTracker := preload("res://shared/zone_presence_tracker.gd")
const WorldLayout := preload("res://data/world/world_layout.gd")
const WorldGenerationSettings := preload("res://data/world/world_generation_settings.gd")


class FakeBoundary extends Node3D:
	var next_zone := ""

	func zone_at(_position: Vector3) -> String:
		return next_zone


func test_el_catalogo_lee_definiciones_editables() -> void:
	var hub := ZoneCatalog.new().definition("hub")
	assert_not_null(hub)
	assert_true(hub.resource_path.ends_with("data/zones/definitions/hub.tres"))
	assert_eq(hub.offset, Vector3.ZERO)


func test_el_layout_del_mundo_guarda_las_reglas_del_mapa() -> void:
	var layout := load("res://data/world/world_layout.tres") as WorldLayout
	assert_not_null(layout)
	assert_true(layout.meadow_maps.has("bend"))
	assert_eq(layout.north_trail, Rect2(4.6, -75.5, 3.8, 46.0))
	assert_eq(layout.validate(ZoneCatalog.new()).size(), 0)

func test_los_parametros_de_generacion_son_editables() -> void:
	var settings := load("res://data/world/world_generation_settings.tres") as WorldGenerationSettings
	assert_not_null(settings)
	assert_eq(settings.tree_clearance, 2)


func test_el_streaming_calcula_la_vecindad_sin_cargar_el_mundo() -> void:
	var streaming := ZoneStreamingController.new()
	streaming.configure(ZoneCatalog.new(), func() -> bool: return true)
	assert_eq(streaming.zones_to_keep("bend"), ["bend", "right", "riverside", "gym", "beach"])
	assert_eq(streaming.zones_to_keep("inexistente"), [])
	assert_false(streaming.has_loaded_zone("hub"))


func test_el_tracker_detecta_solo_un_cambio_valido() -> void:
	var boundary := FakeBoundary.new()
	var tracker := ZonePresenceTracker.new()
	var detected: Array[String] = []
	tracker.configure(boundary, ZoneCatalog.new(), func() -> bool: return false, func() -> Vector3: return Vector3.ZERO)
	tracker.zone_detected.connect(func(zone_id: String): detected.append(zone_id))
	boundary.next_zone = "gym"
	tracker.check_now()
	tracker.set_current_zone("gym")
	tracker.check_now()
	boundary.next_zone = "inexistente"
	tracker.check_now()
	assert_eq(detected, ["gym"])
