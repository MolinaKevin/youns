extends GutTest

const ZoneCatalog := preload("res://data/zones/zone_catalog.gd")
const ZoneDefinition := preload("res://data/zones/zone_definition.gd")
const ZoneStreamingController := preload("res://shared/zone_streaming_controller.gd")
const FIXTURE_SCENE := "res://tests/fixtures/zones/fixture_zone.tscn"


func _definition(id: String, connections: Array[String]) -> ZoneDefinition:
	var definition := ZoneDefinition.new()
	definition.id = id
	definition.scene_path = FIXTURE_SCENE
	definition.connections = connections
	return definition


func test_cambiar_de_zona_descarga_las_lejanas_y_emite_eventos() -> void:
	var definitions: Array[ZoneDefinition] = [
		_definition("a", ["b"]),
		_definition("b", ["a"]),
		_definition("c", []),
	]
	var streaming := ZoneStreamingController.new()
	add_child_autofree(streaming)
	streaming.configure(ZoneCatalog.from_definitions(definitions), func() -> bool: return true)
	var events: Array[String] = []
	streaming.zone_loaded.connect(func(zone_id: String): events.append("+" + zone_id))
	streaming.zone_unloaded.connect(func(zone_id: String): events.append("-" + zone_id))

	streaming.load_now("a")
	streaming.load_now("b")
	streaming.activate("a")
	streaming.load_now("c")
	streaming.activate("c")

	assert_true(streaming.has_loaded_zone("c"))
	assert_false(streaming.has_loaded_zone("a"))
	assert_false(streaming.has_loaded_zone("b"))
	assert_eq(events, ["+a", "+b", "+c", "-a", "-b"])
