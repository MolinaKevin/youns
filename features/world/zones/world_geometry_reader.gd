class_name WorldGeometryReader
extends RefCounted

const AutoDecorationScript := preload("res://features/world/zones/auto_decoration.gd")

var _layout
var _decoration
var _meadow_cache := {}
var _city_cache := {}

func configure(layout, decoration) -> void:
	_layout = layout
	_decoration = decoration

func meadow_triangles(map_path: String, offset: Vector3) -> Dictionary:
	var cache_key := map_path + "@" + str(offset)
	if _meadow_cache.has(cache_key): return _meadow_cache[cache_key]
	var out := {"meadow": PackedVector2Array(), "floor": PackedVector2Array(), "canyon": PackedVector2Array(), "rock": PackedVector2Array()}
	var map: Node3D = (load(map_path) as PackedScene).instantiate()
	_decoration.collect_map_node(map, offset)
	var patterns := {"meadow": ["*Meadow"], "floor": ["*" + _layout.forest_floor_suffix], "canyon": ["*" + _layout.canyon_suffix], "rock": ["*" + _layout.rock_suffix]}
	for key in out:
		var tris: PackedVector2Array = out[key]
		for pattern in patterns[key]:
			for mi in map.find_children(pattern, "MeshInstance3D", true, false):
				if AutoDecorationScript.is_guide(String(mi.name)): continue
				var transform := Transform3D(Basis(), offset) * _transform_in(mi, map)
				for vertex in (mi as MeshInstance3D).mesh.get_faces():
					var point: Vector3 = transform * vertex
					tris.append(Vector2(point.x, point.z))
		out[key] = tris
	map.free()
	_meadow_cache[cache_key] = out
	return out

func city_triangles(offset: Vector3) -> Dictionary:
	var cache_key := str(offset)
	if _city_cache.has(cache_key): return _city_cache[cache_key]
	var out := {"west": PackedVector2Array(), "water": PackedVector2Array(), "mountain": PackedVector2Array()}
	var map: Node3D = (load(_layout.city_map) as PackedScene).instantiate()
	_decoration.collect_map_node(map, offset)
	for node in map.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := ""
		if String(mi.name).begins_with(_layout.west_ground_node): key = "west"
		elif String(mi.name) in _layout.mountain_nodes: key = "mountain"
		elif String(mi.name).begins_with(_layout.river_prefix): key = "water"
		if key.is_empty(): continue
		var tris: PackedVector2Array = out[key]
		var faces := mi.mesh.get_faces()
		var transform := Transform3D(Basis(), offset) * _transform_in(mi, map)
		for i in range(0, faces.size(), 3):
			var a: Vector3 = transform * faces[i]
			var b: Vector3 = transform * faces[i + 1]
			var c: Vector3 = transform * faces[i + 2]
			if key == "mountain" and maxf(a.y, maxf(b.y, c.y)) - offset.y < _layout.mountain_foot: continue
			for point in [a, b, c]: tris.append(Vector2(point.x, point.z))
		out[key] = tris
	map.free()
	_city_cache[cache_key] = out
	return out

func _transform_in(node: Node, root: Node) -> Transform3D:
	var transform := Transform3D()
	while node != root:
		transform = (node as Node3D).transform * transform
		node = node.get_parent()
	return transform
