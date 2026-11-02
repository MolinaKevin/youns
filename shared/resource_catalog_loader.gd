class_name ResourceCatalogLoader
extends RefCounted

## Recorrido determinista de directorios de recursos. Los catálogos aplican su
## propio tipo al resultado, pero comparten el filtrado, el cierre y el orden.

static func resources(directory_path: String, expected_type: Script) -> Array[Resource]:
	var paths := resource_paths(directory_path)
	var result: Array[Resource] = []
	for path in paths:
		var resource := ResourceLoader.load(path)
		if resource != null and is_instance_of(resource, expected_type):
			result.append(resource)
	return result


## Carga tipada por ruta, con error si el `loader` (típicamente una función de
## TypedResourceLoader) devuelve null para algún archivo. Comparten este
## recorrido ItemCatalog y YounCatalog.
static func load_typed_by_path(directory_path: String, loader: Callable, label: String) -> Dictionary:
	var by_path := {}
	for path in resource_paths(directory_path):
		var resource: Resource = loader.call(path)
		if resource == null:
			push_error("%s: no se pudo cargar %s." % [label, path])
			continue
		by_path[path] = resource
	return by_path


## Rutas `.tres` de un directorio (sin subcarpetas), ordenadas. Para catálogos
## que necesitan aplicar su propia carga tipada (con error si el tipo no
## coincide) en vez de descartar el recurso en silencio.
## En un build exportado los .tres se renombran a `<nombre>.tres.remap`; se
## devuelve la ruta original (sin `.remap`) para que ResourceLoader la resuelva
## igual que en el editor.
static func resource_paths(directory_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file := dir.get_next()
	while not file.is_empty():
		if not dir.current_is_dir():
			if file.ends_with(".tres"):
				result.append(directory_path.path_join(file))
			elif file.ends_with(".tres.remap"):
				result.append(directory_path.path_join(file.trim_suffix(".remap")))
		file = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
