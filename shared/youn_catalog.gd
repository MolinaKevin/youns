class_name YounCatalog
extends RefCounted

## Catálogo inmutable de Youns. Centraliza el escaneo de recursos para reglas,
## UI y validación; durante una ejecución los .tres no cambian.

const YOUNS_DIR := "res://data/youns"
static var _all: Array[YounData] = []
static var _by_path := {}
static var _loaded := false


static func all() -> Array[YounData]:
	_ensure_loaded()
	return _all


static func by_path(path: String) -> YounData:
	_ensure_loaded()
	return _by_path.get(path) as YounData


static func paths_for_stage(stage: String, wildcard: Variant = null) -> Array[String]:
	var paths: Array[String] = []
	for data in all():
		if data.stage != stage:
			continue
		if wildcard != null and data.is_wildcard != bool(wildcard):
			continue
		paths.append(data.resource_path)
	return paths


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var filenames := DirAccess.get_files_at(YOUNS_DIR)
	filenames.sort()
	for filename in filenames:
		if not filename.ends_with(".tres"):
			continue
		var path := YOUNS_DIR.path_join(filename)
		var data := load(path) as YounData
		if data == null:
			push_error("YounCatalog: no se pudo cargar %s como YounData." % path)
			continue
		_all.append(data)
		_by_path[path] = data
