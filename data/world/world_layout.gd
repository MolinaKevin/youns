class_name WorldLayout
extends Resource

## Datos específicos del mapa exterior. WorldBoundary sólo arma la grilla,
## paredes y decoración a partir de esta configuración editable.

@export_file("*.glb") var world_guides := ""
@export_file("*.glb") var gym_map := ""
@export_file("*.glb") var city_map := ""
@export var hub_id := "hub"
@export var gym_id := "gym"
@export var hub_ground := Rect2()
@export var north_trail := Rect2()
@export var hub_north_forest := Rect2()
@export var hub_bridge := Rect2()
@export var placeholder_size := 150.0
@export var placeholder_zones: Array[String] = []
@export var meadow_maps: Dictionary = {}
@export var zone_tag_priority: Array[String] = []
@export var forest_floor_suffix := "ForestFloor"
@export var canyon_suffix := "Canyon"
@export var rock_suffix := "Rock"
@export var west_ground_node := "Ground_West"
@export var river_prefix := "river_"
@export var mountain_nodes: Array[String] = []
@export var mountain_foot := 0.6

func validate(catalog: ZoneCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	for path in [world_guides, gym_map, city_map]:
		if path.is_empty() or not ResourceLoader.exists(path): errors.append("No existe mapa '%s'." % path)
	for id in meadow_maps:
		if not catalog.has(id): errors.append("Meadow de zona inexistente '%s'." % id)
		elif not ResourceLoader.exists(meadow_maps[id]): errors.append("No existe meadow '%s'." % meadow_maps[id])
	for id in zone_tag_priority:
		if not catalog.has(id): errors.append("Tag de zona inexistente '%s'." % id)
	return errors
