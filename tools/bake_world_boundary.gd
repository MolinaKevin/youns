extends "res://tools/bake_tool_base.gd"

## Ejecutar desde la raíz:
## godot --headless --path . --script res://tools/bake_world_boundary.gd
##
## Guarda la grilla transitable/zonas y las colisiones de los límites globales.

const WorldBoundary := preload("res://features/world/zones/world_boundary.gd")
const ZoneCatalogScript := preload("res://data/zones/zone_catalog.gd")
const WorldBoundaryBakeDataScript := preload("res://features/world/zones/world_boundary_bake_data.gd")
const WorldBoundaryBakeSignatureScript := preload("res://features/world/zones/world_boundary_bake_signature.gd")
const WorldLayoutScript := preload("res://data/world/world_layout.tres")
const GRID_OUTPUT := "res://assets/maps/world/baked_world_boundary.tres"
const WALLS_OUTPUT := "res://assets/maps/world/baked_world_boundary_walls.scn"


func _init() -> void:
	_disable_autoloads()
	call_deferred("_bake")


func _bake() -> void:
	print("[WorldBoundaryBaker] Generando grilla y límites horneados…")
	var boundary := WorldBoundary.new()
	# Fuerza la ruta fuente: este baker es quien actualiza los artefactos.
	boundary.build(ZoneCatalogScript.new(), false, true, false, false)
	var bake_data := WorldBoundaryBakeDataScript.new()
	bake_data.from_grid(boundary._grid, WorldBoundaryBakeSignatureScript.current(WorldLayoutScript))
	var grid_error := ResourceSaver.save(bake_data, GRID_OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if grid_error != OK:
		_fail("WorldBoundaryBaker: No se pudo guardar %s (%s)." % [GRID_OUTPUT, grid_error], [boundary])
		return
	var root_node := Node3D.new()
	root_node.name = "BakedWorldBoundaryWalls"
	for node_name in ["Walls", "NorthTrail"]:
		var node := boundary.get_node_or_null(node_name) as Node3D
		if node == null:
			_fail("WorldBoundaryBaker: No se generó %s." % node_name, [boundary])
			return
		boundary.remove_child(node)
		root_node.add_child(node)
	_set_owner_recursive(root_node, root_node)
	var packed := PackedScene.new()
	var pack_error := packed.pack(root_node)
	if pack_error != OK:
		_fail("WorldBoundaryBaker: No se pudo empaquetar límites (%s)." % pack_error, [root_node, boundary])
		return
	var walls_error := ResourceSaver.save(packed, WALLS_OUTPUT, ResourceSaver.FLAG_COMPRESS)
	if walls_error != OK:
		_fail("WorldBoundaryBaker: no se pudo guardar %s (%s)." % [WALLS_OUTPUT, walls_error], [root_node, boundary])
		return
	root_node.free()
	boundary.free()
	print("[WorldBoundaryBaker] Listo: %s y %s (%d×%d celdas)." % [GRID_OUTPUT, WALLS_OUTPUT, bake_data.width, bake_data.height])
	quit()
