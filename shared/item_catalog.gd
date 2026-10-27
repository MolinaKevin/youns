class_name ItemCatalog
extends RefCounted

const ITEMS_DIR := "res://data/items"
static var _by_path := {}
static var _by_id := {}
static var _loaded := false


static func by_path(path: String) -> ItemData:
	_ensure_loaded()
	return _by_path.get(path) as ItemData


static func all() -> Array[ItemData]:
	_ensure_loaded()
	var items: Array[ItemData] = []
	for item in _by_path.values():
		items.append(item as ItemData)
	return items


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for filename in DirAccess.get_files_at(ITEMS_DIR):
		if not filename.ends_with(".tres"):
			continue
		var path := ITEMS_DIR.path_join(filename)
		var item := load(path) as ItemData
		if item == null:
			push_error("ItemCatalog: no se pudo cargar %s como ItemData." % path)
			continue
		_by_path[path] = item
		if not item.id.is_empty():
			_by_id[item.id] = item
