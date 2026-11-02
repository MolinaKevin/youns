class_name ItemCatalog
extends RefCounted

const ITEMS_DIR := "res://data/items"
static var _by_path := {}
static var _by_id := {}
static var _loaded := false


static func by_path(path: String) -> ItemData:
	_ensure_loaded()
	return _by_path.get(path) as ItemData

static func by_id(item_id: String) -> ItemData:
	_ensure_loaded()
	return _by_id.get(item_id) as ItemData


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
	_by_path = ResourceCatalogLoader.load_typed_by_path(ITEMS_DIR, TypedResourceLoader.item, "ItemCatalog")
	for item in _by_path.values():
		if item.id.is_empty():
			continue
		if _by_id.has(item.id):
			push_error("ItemCatalog: id duplicado '%s'." % item.id)
			continue
		_by_id[item.id] = item
