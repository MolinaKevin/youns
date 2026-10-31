class_name ResourceCatalogLoader
extends RefCounted

## Recorrido determinista de directorios de recursos. Los catálogos aplican su
## propio tipo al resultado, pero comparten el filtrado, el cierre y el orden.

static func resources(directory_path: String, expected_type: Script) -> Array[Resource]:
	var paths := _resource_paths(directory_path)
	var result: Array[Resource] = []
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource != null and is_instance_of(resource, expected_type):
			result.append(resource)
	return result


static func _resource_paths(directory_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir() and file.ends_with(".tres"):
			result.append(directory_path.path_join(file))
		file = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
