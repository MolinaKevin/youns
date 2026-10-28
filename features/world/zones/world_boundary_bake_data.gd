class_name WorldBoundaryBakeData
extends Resource

## Representación serializable de WorldBoundaryGrid. Se genera con
## tools/bake_world_boundary.gd para no rasterizar todos los mapas al entrar.

@export var source_signature := ""
@export var origin := Vector2.ZERO
@export var width := 0
@export var height := 0
@export var cells := PackedByteArray()
@export var zone_of := PackedByteArray()
@export var zone_names := PackedStringArray()


func from_grid(grid: WorldBoundaryGrid, signature: String) -> void:
	source_signature = signature
	origin = grid.origin
	width = grid.w
	height = grid.h
	cells = grid.cells.duplicate()
	zone_of = grid.zone_of.duplicate()
	zone_names = PackedStringArray(grid.zone_names)


func to_grid() -> WorldBoundaryGrid:
	var grid := WorldBoundaryGrid.new()
	grid.origin = origin
	grid.w = width
	grid.h = height
	grid.cells = cells.duplicate()
	grid.zone_of = zone_of.duplicate()
	grid.zone_names.assign(zone_names)
	return grid
