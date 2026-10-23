class_name CombatMapRenderer
extends RefCounted

## Construcción de elementos visuales que pertenecen al tablero, no a sus reglas.
## CombatMapOverlay sigue siendo dueño de los nodos de preview reutilizables.
func make_ground(width: float, height: float) -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width + 4.0, height + 4.0)
	ground.mesh = plane
	ground.position = Vector3(width * 0.5, -0.02, height * 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.16, 0.20)
	ground.material_override = material
	return ground

func show_disc(mesh_instance: MeshInstance3D, center: Vector2, radius: float) -> void:
	build_tile_disc(mesh_instance, center, radius, 0.0, 0.02)

## Círculo continuo para alcances grandes. A diferencia de build_tile_disc(),
## no crea una celda por cada fracción del tablero.
func show_simple_disc(mesh_instance: MeshInstance3D, center: Vector2, radius: float, height := 0.02) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.002
	mesh.radial_segments = 64
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(center.x, height, center.y)
	mesh_instance.material_override = mesh_instance.get_meta("fill_mat") if mesh_instance.has_meta("fill_mat") else null
	mesh_instance.visible = true

func show_disc_ring(mesh_instance: MeshInstance3D, center: Vector2, radius: float, inner: float) -> void:
	build_tile_disc(mesh_instance, center, radius, inner, 0.02)

func show_footprint(mesh_instance: MeshInstance3D, center: Vector2, radius: float, height: float) -> void:
	build_tile_disc(mesh_instance, center, radius, 0.0, height)

func build_tile_disc(mesh_instance: MeshInstance3D, center: Vector2, radius: float, inner_radius: float, height: float, exclusions: Array = []) -> void:
	const CELL := 0.08
	const BORDER := 0.010
	var half := CELL * 0.5
	var fill_vertices := PackedVector3Array()
	var fill_indices := PackedInt32Array()
	var border_vertices := PackedVector3Array()
	var border_indices := PackedInt32Array()
	for grid_x in range(int(floor((center.x - radius) / CELL)), int(ceil((center.x + radius) / CELL)) + 1):
		for grid_y in range(int(floor((center.y - radius) / CELL)), int(ceil((center.y + radius) / CELL)) + 1):
			var x := (grid_x + 0.5) * CELL
			var z := (grid_y + 0.5) * CELL
			var closest := Vector2(clampf(center.x, x - half, x + half), clampf(center.y, z - half, z + half))
			if closest.distance_to(center) > radius or (inner_radius > 0.0 and Vector2(x, z).distance_to(center) < inner_radius):
				continue
			var excluded := false
			for exclusion in exclusions:
				if Vector2(x, z).distance_to(exclusion["pos"]) <= exclusion["radius"]:
					excluded = true
					break
			if excluded:
				continue
			_append_cell(fill_vertices, fill_indices, border_vertices, border_indices, x, z, half, BORDER, height)
	apply_two_surface_mesh(mesh_instance, fill_vertices, fill_indices, border_vertices, border_indices)

## TODO: reutilizar desde un preview que necesite casillas planas. Los previews
## actuales se apoyan sobre el terreno con `build_cells_on_terrain`.
func build_flat_cells(mesh_instance: MeshInstance3D, cells: Array[Vector2i], height: float) -> void:
	const CELL := 0.08
	const BORDER := 0.010
	var half := CELL * 0.5
	var fill_vertices := PackedVector3Array()
	var fill_indices := PackedInt32Array()
	var border_vertices := PackedVector3Array()
	var border_indices := PackedInt32Array()
	for cell in cells:
		var x: float = (cell.x + 0.5) * CELL
		var z: float = (cell.y + 0.5) * CELL
		_append_cell(fill_vertices, fill_indices, border_vertices, border_indices, x, z, half, BORDER, height)
	apply_two_surface_mesh(mesh_instance, fill_vertices, fill_indices, border_vertices, border_indices)

## Dibuja celdas centradas en XZ; cada centro trae su propia altura Y.
## Los sistemas de overlay deciden qué celdas incluir y el renderer sólo arma
## la malla correspondiente.
func build_cells_at_heights(mesh_instance: MeshInstance3D, centers: PackedVector3Array, cell_size: float, border: float = 0.010) -> void:
	var count := centers.size()
	var fill_vertices := PackedVector3Array(); fill_vertices.resize(count * 4)
	var fill_indices := PackedInt32Array(); fill_indices.resize(count * 6)
	var border_vertices := PackedVector3Array(); border_vertices.resize(count * 16)
	var border_indices := PackedInt32Array(); border_indices.resize(count * 24)
	var half := cell_size * 0.5
	for cell_index in count:
		var center := centers[cell_index]
		var x0 := center.x - half
		var x1 := center.x + half
		var z0 := center.z - half
		var z1 := center.z + half
		var y := center.y
		var vertex_index := cell_index * 4
		fill_vertices[vertex_index] = Vector3(x0 + border, y, z0 + border)
		fill_vertices[vertex_index + 1] = Vector3(x1 - border, y, z0 + border)
		fill_vertices[vertex_index + 2] = Vector3(x1 - border, y, z1 - border)
		fill_vertices[vertex_index + 3] = Vector3(x0 + border, y, z1 - border)
		var triangle_index := cell_index * 6
		fill_indices[triangle_index] = vertex_index; fill_indices[triangle_index + 1] = vertex_index + 1; fill_indices[triangle_index + 2] = vertex_index + 2
		fill_indices[triangle_index + 3] = vertex_index; fill_indices[triangle_index + 4] = vertex_index + 2; fill_indices[triangle_index + 5] = vertex_index + 3
		_append_quad(border_vertices, border_indices, cell_index * 16, cell_index * 24, x0, z0, x1, z0 + border, y + 0.001)
		_append_quad(border_vertices, border_indices, cell_index * 16 + 4, cell_index * 24 + 6, x0, z1 - border, x1, z1, y + 0.001)
		_append_quad(border_vertices, border_indices, cell_index * 16 + 8, cell_index * 24 + 12, x0, z0 + border, x0 + border, z1 - border, y + 0.001)
		_append_quad(border_vertices, border_indices, cell_index * 16 + 12, cell_index * 24 + 18, x1 - border, z0 + border, x1, z1 - border, y + 0.001)
	apply_two_surface_mesh(mesh_instance, fill_vertices, fill_indices, border_vertices, border_indices)

func build_cone_disc(mesh_instance: MeshInstance3D, origin: Vector2, direction: Vector2, max_range: float, half_angle_deg: float) -> void:
	const CELL := 0.08
	const BORDER := 0.010
	const HEIGHT := 0.02
	var half := CELL * 0.5
	var half_angle := deg_to_rad(half_angle_deg)
	var normalized_direction := direction.normalized()
	var fill_vertices := PackedVector3Array()
	var fill_indices := PackedInt32Array()
	var border_vertices := PackedVector3Array()
	var border_indices := PackedInt32Array()
	for grid_x in range(int(floor((origin.x - max_range) / CELL)), int(ceil((origin.x + max_range) / CELL)) + 1):
		for grid_y in range(int(floor((origin.y - max_range) / CELL)), int(ceil((origin.y + max_range) / CELL)) + 1):
			var x := (grid_x + 0.5) * CELL
			var z := (grid_y + 0.5) * CELL
			var closest := Vector2(clampf(origin.x, x - half, x + half), clampf(origin.y, z - half, z + half))
			var to_cell := Vector2(x, z) - origin
			if closest.distance_to(origin) > max_range or to_cell.length() < 0.001 or absf(normalized_direction.angle_to(to_cell.normalized())) > half_angle:
				continue
			_append_cell(fill_vertices, fill_indices, border_vertices, border_indices, x, z, half, BORDER, HEIGHT)
	apply_two_surface_mesh(mesh_instance, fill_vertices, fill_indices, border_vertices, border_indices)

func apply_two_surface_mesh(mesh_instance: MeshInstance3D, fill_vertices: PackedVector3Array, fill_indices: PackedInt32Array, border_vertices: PackedVector3Array, border_indices: PackedInt32Array) -> void:
	if fill_vertices.is_empty():
		mesh_instance.visible = false
		return
	var mesh := ArrayMesh.new()
	var fill_arrays := []; fill_arrays.resize(Mesh.ARRAY_MAX)
	fill_arrays[Mesh.ARRAY_VERTEX] = fill_vertices; fill_arrays[Mesh.ARRAY_INDEX] = fill_indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fill_arrays)
	var border_arrays := []; border_arrays.resize(Mesh.ARRAY_MAX)
	border_arrays[Mesh.ARRAY_VERTEX] = border_vertices; border_arrays[Mesh.ARRAY_INDEX] = border_indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, border_arrays)
	mesh_instance.mesh = mesh
	mesh_instance.set_surface_override_material(0, mesh_instance.get_meta("fill_mat") if mesh_instance.has_meta("fill_mat") else null)
	mesh_instance.set_surface_override_material(1, mesh_instance.get_meta("bord_mat") if mesh_instance.has_meta("bord_mat") else null)
	mesh_instance.visible = true

func visual_cell_center(world_pos: Vector2) -> Vector2:
	return Vector2(floor(world_pos.x / 0.08) * 0.08 + 0.04, floor(world_pos.y / 0.08) * 0.08 + 0.04)

func show_single_cell(mesh_instance: MeshInstance3D, center: Vector2, terrain_height: float) -> void:
	build_tile_disc(mesh_instance, center, 0.04, 0.0, terrain_height + 0.03)

func build_line_pattern(mesh_instance: MeshInstance3D, origin: Vector2, direction: Vector2, length: float, width: float, start_offset: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(width, CombatGrid.CELL), 0.018, maxf(length, CombatGrid.CELL))
	mesh_instance.mesh = mesh
	var center: Vector2 = origin + direction * (start_offset + length * 0.5)
	mesh_instance.position = Vector3(center.x, 0.026, center.y)
	mesh_instance.rotation.y = atan2(direction.x, direction.y)
	mesh_instance.material_override = material
	mesh_instance.visible = true

func _append_cell(fill_vertices: PackedVector3Array, fill_indices: PackedInt32Array, border_vertices: PackedVector3Array, border_indices: PackedInt32Array, x: float, z: float, half: float, border: float, height: float) -> void:
	var fill_index := fill_vertices.size()
	fill_vertices.append_array([Vector3(x-half+border, height, z-half+border), Vector3(x+half-border, height, z-half+border), Vector3(x+half-border, height, z+half-border), Vector3(x-half+border, height, z+half-border)])
	fill_indices.append_array([fill_index, fill_index + 1, fill_index + 2, fill_index, fill_index + 2, fill_index + 3])
	for strip in [[x-half, z-half, x+half, z-half+border], [x-half, z+half-border, x+half, z+half], [x-half, z-half+border, x-half+border, z+half-border], [x+half-border, z-half+border, x+half, z+half-border]]:
		var border_index := border_vertices.size()
		border_vertices.append_array([Vector3(strip[0], height + 0.001, strip[1]), Vector3(strip[2], height + 0.001, strip[1]), Vector3(strip[2], height + 0.001, strip[3]), Vector3(strip[0], height + 0.001, strip[3])])
		border_indices.append_array([border_index, border_index + 1, border_index + 2, border_index, border_index + 2, border_index + 3])

func _append_quad(vertices: PackedVector3Array, indices: PackedInt32Array, vertex_index: int, index_index: int,
		x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	vertices[vertex_index] = Vector3(x0, y, z0)
	vertices[vertex_index + 1] = Vector3(x1, y, z0)
	vertices[vertex_index + 2] = Vector3(x1, y, z1)
	vertices[vertex_index + 3] = Vector3(x0, y, z1)
	indices[index_index] = vertex_index; indices[index_index + 1] = vertex_index + 1; indices[index_index + 2] = vertex_index + 2
	indices[index_index + 3] = vertex_index; indices[index_index + 4] = vertex_index + 2; indices[index_index + 5] = vertex_index + 3
