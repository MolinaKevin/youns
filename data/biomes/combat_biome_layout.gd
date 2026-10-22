class_name CombatBiomeLayout
extends Resource

func populate_map(map: Node3D) -> void:
	# Las subclases describen el tablero usando la API de MapArea. Así no conocen
	# el formato interno de `solid_obstacles`.
	map.clear_biome_obstacles()

func build_visuals(map: Node3D) -> void:
	var solid_mat := StandardMaterial3D.new()
	solid_mat.albedo_color = Color(0.30, 0.25, 0.20)
	solid_mat.roughness = 0.9

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.50, 0.47, 0.43)
	rock_mat.roughness = 0.95

	var bridge_mat := StandardMaterial3D.new()
	bridge_mat.albedo_color = Color(0.55, 0.40, 0.22, 0.80)
	bridge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bridge_mat.roughness = 0.7

	for obs: Dictionary in map.solid_obstacles:
		var pos: Vector2 = obs["pos"]
		var obs_type: String = obs.get("type", "solid")
		var mi := MeshInstance3D.new()
		match obs_type:
			"platform":
				_build_platform(map, mi, obs, pos)
				continue
			"bridge":
				var size: Vector2 = obs["box"]
				var box := BoxMesh.new()
				box.size = Vector3(size.x, 0.22, size.y)
				mi.mesh = box
				mi.position = Vector3(pos.x, 0.9, pos.y)
				mi.material_override = bridge_mat
			"tree":
				map.build_initial_tree_mesh(mi, obs, pos)
			"rock":
				map.build_initial_rock_mesh(mi, obs, pos, rock_mat)
			_:
				if obs.has("box"):
					var size: Vector2 = obs["box"]
					var box := BoxMesh.new()
					box.size = Vector3(size.x, size.x * 1.5, size.y)
					mi.mesh = box
					mi.position = Vector3(pos.x, box.size.y * 0.5, pos.y)
				else:
					var radius: float = obs["radius"]
					var cylinder := CylinderMesh.new()
					cylinder.top_radius = radius
					cylinder.bottom_radius = radius
					cylinder.height = radius * 2.5
					mi.mesh = cylinder
					mi.position = Vector3(pos.x, cylinder.height * 0.5, pos.y)
				mi.material_override = solid_mat
		map.add_child(mi)
		obs["node"] = mi

func _build_platform(map: Node3D, platform: MeshInstance3D, obs: Dictionary, pos: Vector2) -> void:
	var size: Vector2 = obs["box"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.30, 0.22)
	material.roughness = 0.8
	var box := BoxMesh.new()
	box.size = Vector3(size.x, map.PLATFORM_HEIGHT, size.y)
	platform.mesh = box
	platform.position = Vector3(pos.x, map.PLATFORM_HEIGHT * 0.5, pos.y)
	platform.material_override = material
	map.add_child(platform)

	var ramp_material := StandardMaterial3D.new()
	ramp_material.albedo_color = Color(0.45, 0.38, 0.26)
	ramp_material.roughness = 0.85
	ramp_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var half_size := size * 0.5
	for ramp: Dictionary in obs.get("ramps", []):
		var half_width: float = ramp.get("width", 2.0) * 0.5
		var ramp_mesh := MeshInstance3D.new()
		var vertices := _ramp_vertices(map, pos, half_size, half_width, ramp["side"])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		ramp_mesh.mesh = mesh
		ramp_mesh.material_override = ramp_material
		map.add_child(ramp_mesh)

func _ramp_vertices(map: Node3D, pos: Vector2, half_size: Vector2, half_width: float, side: String) -> PackedVector3Array:
	var h: float = map.PLATFORM_HEIGHT
	var depth: float = map.RAMP_DEPTH
	match side:
		"south": return PackedVector3Array([Vector3(pos.x - half_width, h, pos.y + half_size.y), Vector3(pos.x + half_width, h, pos.y + half_size.y), Vector3(pos.x + half_width, 0.0, pos.y + half_size.y + depth), Vector3(pos.x - half_width, 0.0, pos.y + half_size.y + depth)])
		"north": return PackedVector3Array([Vector3(pos.x - half_width, 0.0, pos.y - half_size.y - depth), Vector3(pos.x + half_width, 0.0, pos.y - half_size.y - depth), Vector3(pos.x + half_width, h, pos.y - half_size.y), Vector3(pos.x - half_width, h, pos.y - half_size.y)])
		"east": return PackedVector3Array([Vector3(pos.x + half_size.x, h, pos.y - half_width), Vector3(pos.x + half_size.x + depth, 0.0, pos.y - half_width), Vector3(pos.x + half_size.x + depth, 0.0, pos.y + half_width), Vector3(pos.x + half_size.x, h, pos.y + half_width)])
		"west": return PackedVector3Array([Vector3(pos.x - half_size.x - depth, 0.0, pos.y - half_width), Vector3(pos.x - half_size.x, h, pos.y - half_width), Vector3(pos.x - half_size.x, h, pos.y + half_width), Vector3(pos.x - half_size.x - depth, 0.0, pos.y + half_width)])
		_: return PackedVector3Array()
