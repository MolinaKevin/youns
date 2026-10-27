class_name WorldDecorationBuilder
extends RefCounted

const AutoDecorationScript := preload("res://features/world/zones/auto_decoration.gd")
const ForestBuilder := preload("res://features/world/zones/forest_builder.gd")
const BakeSignature := preload("res://features/world/zones/world_decoration_bake_signature.gd")
const DebugLogging := preload("res://shared/debug_logging.gd")

## La decoración se hornea con tools/bake_world_decoration.gd. El editor usa
## el mismo algoritmo procedural una vez; el juego sólo carga la escena lista.
const USE_BAKED_WORLD_DECORATION := true
const BAKED_WORLD_DECORATION := "res://assets/maps/world/baked_world_decoration.scn"

var _decoration := AutoDecorationScript.new()
var _force_procedural := false
var _build_tree_meshes := true
var _baked_tree_positions: Array[Vector3] = []


func prepare(force_procedural: bool, build_tree_meshes := true) -> void:
	_force_procedural = force_procedural
	_build_tree_meshes = build_tree_meshes


func collect_map_node(map: Node, offset: Vector3) -> void:
	if _uses_baked_world_decoration():
		return
	_decoration.add_node(map, offset)


func build(parent: Node3D, grid: WorldBoundaryGrid, layout: WorldLayout, catalog: ZoneCatalog, clearance: int, spacing: float, tree_seed: int) -> void:
	if _uses_baked_world_decoration():
		_add_baked_world_decoration(parent, layout, tree_seed)
		return
	if ResourceLoader.exists(layout.gym_map): _decoration.add_map(layout.gym_map, catalog.definition(layout.gym_id).offset)
	var node := Node3D.new()
	node.name = "AutoDecoration"
	parent.add_child(node)
	if ResourceLoader.exists(layout.world_guides):
		_decoration.add_map(layout.world_guides, Vector3.ZERO)
	else:
		push_warning("WorldDecorationBuilder: no está %s" % layout.world_guides)
	_decoration.build(node, grid, clearance, spacing, tree_seed, _build_tree_meshes)


func tree_positions() -> Array[Vector3]:
	if _uses_baked_world_decoration():
		return _baked_tree_positions
	return _decoration.built_tree_positions()


func _uses_baked_world_decoration() -> bool:
	return USE_BAKED_WORLD_DECORATION and not _force_procedural and ResourceLoader.exists(BAKED_WORLD_DECORATION)


func _add_baked_world_decoration(parent: Node3D, layout: WorldLayout, tree_seed: int) -> void:
	var baked := (load(BAKED_WORLD_DECORATION) as PackedScene).instantiate() as Node3D
	if baked == null:
		push_error("WorldDecorationBuilder: no se pudo instanciar %s" % BAKED_WORLD_DECORATION)
		return
	_warn_if_bake_is_stale(baked, layout)
	_baked_tree_positions.clear()
	for position in baked.get_meta("tree_positions", []):
		if position is Vector3:
			_baked_tree_positions.append(position)
	parent.add_child(baked)
	_add_baked_trees(baked, tree_seed)
	if DebugLogging.verbose_enabled():
		print("[WorldDecorationBuilder] Decoración global horneada cargada (%d árboles)." % _baked_tree_positions.size())


func _warn_if_bake_is_stale(baked: Node3D, layout: WorldLayout) -> void:
	if not OS.is_debug_build():
		return
	var baked_signature := String(baked.get_meta("source_signature", ""))
	var current_signature := BakeSignature.current(layout)
	if baked_signature != current_signature:
		push_warning("WorldDecorationBuilder: la decoración horneada está desactualizada. Ejecutá: godot --headless --path . --script res://tools/bake_world_decoration.gd")


func _add_baked_trees(parent: Node3D, tree_seed: int) -> void:
	if _baked_tree_positions.is_empty():
		return
	var templates := ForestBuilder.library_templates(AutoDecorationScript.TREE_GROUP)
	if templates.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed + 1
	var trees: Array = []
	for position in _baked_tree_positions:
		trees.append([rng.randi() % templates.size(), ForestBuilder.random_tree_transform(rng, position)])
	ForestBuilder.add_trees(parent, templates, trees)
