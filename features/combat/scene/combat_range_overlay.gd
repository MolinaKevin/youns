class_name CombatRangeOverlay
extends RefCounted

## Compone previews que necesitan reglas espaciales (terreno y línea de visión)
## y delega la malla resultante al renderer. No modifica el estado del combate.
const VISUAL_CELL := CombatGrid.CELL

var terrain: CombatTerrain
var queries: CombatMapQueries
var renderer: CombatMapRenderer

func render_path_preview(mesh_instance: MeshInstance3D, path: Array[Vector2]) -> void:
	if path.size() < 2:
		mesh_instance.visible = false
		return
	var centers := PackedVector3Array()
	var seen := {}
	for segment in range(path.size() - 1):
		var from: Vector2 = path[segment]
		var to: Vector2 = path[segment + 1]
		var steps := maxi(1, int(from.distance_to(to) / (VISUAL_CELL * 0.4)))
		for step in range(steps + 1):
			var point := from.lerp(to, float(step) / float(steps))
			var cell := Vector2i(int(floor(point.x / VISUAL_CELL)), int(floor(point.y / VISUAL_CELL)))
			if cell in seen:
				continue
			seen[cell] = true
			var center := Vector2((cell.x + 0.5) * VISUAL_CELL, (cell.y + 0.5) * VISUAL_CELL)
			centers.append(Vector3(center.x, terrain.height_at(center) + 0.025, center.y))
	renderer.build_cells_at_heights(mesh_instance, centers, VISUAL_CELL)

func build_cells_on_terrain(mesh_instance: MeshInstance3D, cells: Array) -> void:
	var centers := PackedVector3Array()
	centers.resize(cells.size())
	var index := 0
	for cell: Vector2i in cells:
		var center := CombatGrid.to_world(cell)
		centers[index] = Vector3(center.x, terrain.cell_height(cell, center) + 0.02, center.y)
		index += 1
	renderer.build_cells_at_heights(mesh_instance, centers, CombatGrid.CELL)

func show_disc_with_los(mesh_instance: MeshInstance3D, origin: Vector2, radius: float,
		elevation: int, block_rocks: bool, block_bridges: bool) -> void:
	var centers := PackedVector3Array()
	var half := VISUAL_CELL * 0.5
	for grid_x in range(int(floor((origin.x - radius) / VISUAL_CELL)), int(ceil((origin.x + radius) / VISUAL_CELL)) + 1):
		for grid_y in range(int(floor((origin.y - radius) / VISUAL_CELL)), int(ceil((origin.y + radius) / VISUAL_CELL)) + 1):
			var center := Vector2((grid_x + 0.5) * VISUAL_CELL, (grid_y + 0.5) * VISUAL_CELL)
			var closest := Vector2(clampf(origin.x, center.x - half, center.x + half), clampf(origin.y, center.y - half, center.y + half))
			if closest.distance_to(origin) > radius:
				continue
			if terrain.tile_in_obstacle(center, elevation):
				continue
			if not queries.line_of_sight_clear(origin, center, block_rocks, block_bridges, elevation, elevation):
				continue
			centers.append(Vector3(center.x, terrain.height_at(center) + 0.02, center.y))
	renderer.build_cells_at_heights(mesh_instance, centers, VISUAL_CELL)
