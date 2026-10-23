class_name WorldWalkabilityBuilder
extends RefCounted

## Rasteriza la geometría ya leída de los mapas en la grilla transitable y la
## etiqueta con su zona. No crea nodos físicos ni decoración.

func build(layout: WorldLayout, hub_offset: Vector3, gym_rect: Rect2, walkable_rects: Array[Rect2], placeholder_rects: Dictionary, hub_bridge: Rect2, meadows: Dictionary, meadow_tris: PackedVector2Array, floor_tris: PackedVector2Array, rock_tris: PackedVector2Array, west_tris: PackedVector2Array, water_tris: PackedVector2Array, mountain_tris: PackedVector2Array, margin: float) -> WorldBoundaryGrid:
	var grid := WorldBoundaryGrid.new()
	var bounds := gym_rect
	for rect in walkable_rects: bounds = bounds.merge(rect)
	for tris in [meadow_tris, floor_tris, rock_tris, west_tris, water_tris, mountain_tris]:
		for point in tris: bounds = bounds.expand(point)
	grid.setup(bounds.grow(margin))
	for rect in walkable_rects: grid.fill_rect(rect, WorldBoundaryGrid.WALKABLE)
	for tris in [meadow_tris, west_tris]:
		for i in range(0, tris.size(), 3): grid.fill_triangle(tris[i], tris[i + 1], tris[i + 2])
	grid.fill_rect(gym_rect, WorldBoundaryGrid.RESERVED, true)
	grid.fill_rect(_offset_rect(layout.hub_north_forest, hub_offset), WorldBoundaryGrid.CLEAR, true)
	for i in range(0, floor_tris.size(), 3): grid.fill_triangle(floor_tris[i], floor_tris[i + 1], floor_tris[i + 2], WorldBoundaryGrid.CLEAR, true)
	for i in range(0, water_tris.size(), 3): grid.fill_triangle(water_tris[i], water_tris[i + 1], water_tris[i + 2], WorldBoundaryGrid.CLEAR)
	grid.fill_rect(hub_bridge, WorldBoundaryGrid.WALKABLE)
	for i in range(0, mountain_tris.size(), 3): grid.fill_triangle(mountain_tris[i], mountain_tris[i + 1], mountain_tris[i + 2], WorldBoundaryGrid.CLEAR)
	for i in range(0, rock_tris.size(), 3): grid.fill_triangle(rock_tris[i], rock_tris[i + 1], rock_tris[i + 2], WorldBoundaryGrid.CLEAR)
	grid.tag_rect(walkable_rects[0], layout.hub_id)
	grid.tag_rect(layout.north_trail, layout.hub_id)
	grid.tag_rect(hub_bridge, layout.hub_id)
	for tris in [west_tris, mountain_tris]:
		for i in range(0, tris.size(), 3): grid.tag_triangle(tris[i], tris[i + 1], tris[i + 2], layout.hub_id)
	for id in layout.zone_tag_priority:
		if placeholder_rects.has(id): grid.tag_rect(placeholder_rects[id], id)
		if meadows.has(id):
			var tris: PackedVector2Array = meadows[id]
			for i in range(0, tris.size(), 3): grid.tag_triangle(tris[i], tris[i + 1], tris[i + 2], id)
	grid.tag_rect(gym_rect, layout.gym_id)
	return grid

func _offset_rect(rect: Rect2, offset: Vector3) -> Rect2:
	return Rect2(rect.position + Vector2(offset.x, offset.z), rect.size)
