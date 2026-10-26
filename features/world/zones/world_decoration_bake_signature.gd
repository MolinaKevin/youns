class_name WorldDecorationBakeSignature
extends RefCounted

## Huella de las entradas que determinan la decoración horneada. Sirve para
## advertir durante desarrollo si un .glb, una guía o el algoritmo cambió
## después de ejecutar tools/bake_world_decoration.gd.

const SIGNATURE_VERSION := 1

const PIPELINE_FILES := [
	"res://features/world/zones/auto_decoration.gd",
	"res://features/world/zones/world_boundary.gd",
	"res://features/world/zones/world_geometry_reader.gd",
	"res://features/world/zones/world_walkability_builder.gd",
	"res://data/world/world_layout.tres",
	"res://data/world/world_generation_settings.tres",
]


static func current(layout: WorldLayout) -> String:
	var paths: Array[String] = []
	paths.append_array(PIPELINE_FILES)
	paths.append_array([layout.world_guides, layout.gym_map, layout.city_map])
	for map_path in layout.meadow_maps.values():
		paths.append(String(map_path))
	paths.sort()
	paths = _unique(paths)

	var entries: PackedStringArray = []
	for path in paths:
		entries.append("%s:%s" % [path, _file_hash(path)])
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update("\n".join(entries).to_utf8_buffer())
	return "%d:%s" % [SIGNATURE_VERSION, hasher.finish().hex_encode()]


static func _file_hash(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return "MISSING"
	return FileAccess.get_sha256(path)


static func _unique(paths: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for path in paths:
		if not path.is_empty() and path not in unique:
			unique.append(path)
	return unique
