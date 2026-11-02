class_name ResourceCatalogIndex
extends RefCounted

## Carga un directorio de recursos tipados en un diccionario id -> recurso,
## descartando (con error) los que no tengan id o repitan uno ya visto.
## Comparten este control de flujo zone_catalog.gd y world_construction_catalog.gd.

static func load_by_id(directory_path: String, expected_type: Script, label: String) -> Dictionary:
	var by_id := {}
	var errors := PackedStringArray()
	for resource in ResourceCatalogLoader.resources(directory_path, expected_type):
		var id: String = resource.get("id")
		if id.is_empty():
			errors.append("%s inválida '%s'." % [label, resource.resource_path])
			continue
		if by_id.has(id):
			errors.append("Id de %s duplicado '%s'." % [label, id])
			continue
		by_id[id] = resource
	return {"by_id": by_id, "errors": errors}
