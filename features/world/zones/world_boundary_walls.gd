class_name WorldBoundaryWalls
extends RefCounted

const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")
const CollisionLayers := preload("res://shared/world_collision_layers.gd")

func build(parent: Node3D, grid: WorldBoundaryGrid, layout: WorldLayout, wall_height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	parent.add_child(body)
	for iz in range(1, grid.h):
		var start := -1
		for ix in range(grid.w + 1):
			var edge := ix < grid.w and grid.needs_wall(grid.cell_at(ix, iz - 1), grid.cell_at(ix, iz))
			if edge and start < 0: start = ix
			elif not edge and start >= 0:
				var z := grid.origin.y + iz * WorldBoundaryGrid.CELL
				ForestBuilder.add_wall_between(body, Vector3(grid.origin.x + start * WorldBoundaryGrid.CELL, 0, z), Vector3(grid.origin.x + ix * WorldBoundaryGrid.CELL, 0, z), wall_height)
				start = -1
	for ix in range(1, grid.w):
		var start := -1
		for iz in range(grid.h + 1):
			var edge := iz < grid.h and grid.needs_wall(grid.cell_at(ix - 1, iz), grid.cell_at(ix, iz))
			if edge and start < 0: start = iz
			elif not edge and start >= 0:
				var x := grid.origin.x + ix * WorldBoundaryGrid.CELL
				ForestBuilder.add_wall_between(body, Vector3(x, 0, grid.origin.y + start * WorldBoundaryGrid.CELL), Vector3(x, 0, grid.origin.y + iz * WorldBoundaryGrid.CELL), wall_height)
				start = -1
	var size := Vector3(layout.north_trail.size.x, 0.1, layout.north_trail.size.y)
	var trail := StaticBody3D.new()
	trail.name = "NorthTrail"
	trail.collision_layer = CollisionLayers.GROUND
	trail.position = Vector3(layout.north_trail.get_center().x, -0.04, layout.north_trail.get_center().y)
	parent.add_child(trail)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	trail.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.3)
	mat.roughness = 1.0
	mesh.material = mat
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	trail.add_child(visual)

func set_trail_visible(parent: Node3D, open: bool) -> void:
	var trail := parent.get_node_or_null("NorthTrail")
	if trail == null: return
	for mi in trail.find_children("*", "MeshInstance3D", false, false):
		(mi as MeshInstance3D).visible = open
