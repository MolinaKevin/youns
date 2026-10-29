class_name AutoDecorationBuilder
extends RefCounted

const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")

## Orquesta la construcción de mallas; las reglas geométricas permanecen en
## AutoDecoration para que pueda seguir usándose como acumulador y fixture.

static func build(decoration: AutoDecoration, parent: Node3D, grid: WorldBoundaryGrid, clearance: int, spacing: float, tree_seed: int, build_tree_meshes: bool) -> void:
	var ground := decoration.ground_triangles()
	if not ground.is_empty():
		parent.add_child(decoration.ground_mesh(ground))
	var water := decoration.water_triangles()
	if not water.is_empty():
		parent.add_child(decoration.water_mesh(water))
	var positions := decoration.tree_positions(grid, clearance, spacing, tree_seed)
	decoration.set_built_tree_positions(positions)
	if not build_tree_meshes or positions.is_empty():
		return
	var templates := ForestBuilder.library_templates(AutoDecoration.TREE_GROUP)
	if templates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed + 1
	var trees: Array = []
	for p in positions:
		trees.append([rng.randi() % templates.size(), ForestBuilder.random_tree_transform(rng, p)])
	ForestBuilder.add_trees(parent, templates, trees)
