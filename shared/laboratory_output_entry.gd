class_name LaboratoryOutputEntry
extends RefCounted

## Forma persistida del depósito del laboratorio. Sigue siendo Dictionary para
## serializarse en PlayerSaveData, pero evita dispersar sus claves.

const ID := "id"
const NAME := "name"
const COUNT := "count"
const DATA_PATH := "data_path"

static func make(item_id: String, item_name: String, count: int, data_path: String = "") -> Dictionary:
	var entry := {ID: item_id, NAME: item_name, COUNT: count}
	if not data_path.is_empty():
		entry[DATA_PATH] = data_path
	return entry

static func count_of(entry: Dictionary) -> int:
	return int(entry.get(COUNT, 0))

static func data_path_of(entry: Dictionary) -> String:
	return str(entry.get(DATA_PATH, ""))
