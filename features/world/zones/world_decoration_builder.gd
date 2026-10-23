class_name WorldDecorationBuilder
extends RefCounted

const AutoDecorationScript := preload("res://features/world/zones/auto_decoration.gd")

var _decoration := AutoDecorationScript.new()

func collect_map_node(map: Node, offset: Vector3) -> void:
	_decoration.add_node(map, offset)

func build(parent: Node3D, grid: WorldBoundaryGrid, layout: WorldLayout, catalog: ZoneCatalog, clearance: int, spacing: float, tree_seed: int) -> void:
	if ResourceLoader.exists(layout.gym_map): _decoration.add_map(layout.gym_map, catalog.definition(layout.gym_id).offset)
	if ResourceLoader.exists(layout.world_guides): _decoration.add_map(layout.world_guides, Vector3.ZERO)
	else: push_warning("WorldDecorationBuilder: no está %s" % layout.world_guides)
	var node := Node3D.new()
	node.name = "AutoDecoration"
	parent.add_child(node)
	_decoration.build(node, grid, clearance, spacing, tree_seed)

func tree_positions() -> Array[Vector3]:
	return _decoration.built_tree_positions()
