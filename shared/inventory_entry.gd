class_name InventoryEntry
extends RefCounted

## Contrato de la entrada persistida del inventario. El guardado mantiene
## diccionarios por compatibilidad, pero su forma se construye y normaliza en
## un único lugar.

const ID := "id"
const NAME := "name"
const ICON := "icon"
const DATA_PATH := "data_path"
const COUNT := "count"


static func make(data: ItemData, count: int) -> Dictionary:
	if data == null:
		return {}
	return {
		ID: data.id,
		NAME: data.name,
		ICON: data.icon.resource_path if data.icon else "",
		DATA_PATH: data.resource_path,
		COUNT: maxi(0, count),
	}


static func count_of(entry: Dictionary) -> int:
	return maxi(0, int(entry.get(COUNT, 0)))


static func item_id(entry: Dictionary) -> String:
	return str(entry.get(ID, ""))


static func data_path(entry: Dictionary) -> String:
	return str(entry.get(DATA_PATH, ""))
