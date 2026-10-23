class_name ZoneCatalog
extends RefCounted

## Catálogo único del grafo exterior. Las definiciones son recursos .tres para
## editar conexiones, escena y offset desde el Inspector.

var _definitions: Dictionary = {}
var _load_errors := PackedStringArray()


func _init() -> void:
	var paths := DirAccess.get_files_at("res://data/zones/definitions")
	paths.sort()
	for path in paths:
		if not path.ends_with(".tres"):
			continue
		var zone_definition := load("res://data/zones/definitions/" + path) as ZoneDefinition
		if zone_definition == null or zone_definition.id.is_empty():
			_load_errors.append("Definición inválida '%s'." % path)
			continue
		if _definitions.has(zone_definition.id):
			_load_errors.append("Id de zona duplicado '%s' (%s)." % [zone_definition.id, path])
			continue
		_definitions[zone_definition.id] = zone_definition


static func from_definitions(definitions: Array[ZoneDefinition]) -> ZoneCatalog:
	var catalog := ZoneCatalog.new()
	catalog._definitions.clear()
	catalog._load_errors.clear()
	for zone_definition in definitions:
		if zone_definition == null or zone_definition.id.is_empty():
			catalog._load_errors.append("Definición de fixture inválida.")
			continue
		if catalog._definitions.has(zone_definition.id):
			catalog._load_errors.append("Id de zona duplicado '%s'." % zone_definition.id)
			continue
		catalog._definitions[zone_definition.id] = zone_definition
	return catalog


func definition(id: String) -> ZoneDefinition:
	return _definitions.get(id) as ZoneDefinition


func has(id: String) -> bool:
	return _definitions.has(id)


func ids() -> Array[String]:
	var result: Array[String] = []
	for id in _definitions:
		result.append(id)
	return result


func validate() -> PackedStringArray:
	var errors := _load_errors.duplicate()
	if _definitions.is_empty():
		errors.append("No hay definiciones de zona.")
	for id in _definitions:
		var zone_definition: ZoneDefinition = _definitions[id]
		if zone_definition.id != id or zone_definition.scene_path.is_empty() or not ResourceLoader.exists(zone_definition.scene_path):
			errors.append("Zona inválida '%s': escena '%s'." % [id, zone_definition.scene_path])
		for connection in zone_definition.connections:
			if not _definitions.has(connection):
				errors.append("Zona '%s' conecta con una zona inexistente '%s'." % [id, connection])
	return errors
