extends SceneTree

## Ejecutar una vez desde la raíz del proyecto:
## godot --headless --path . --script res://tools/bake_world_decoration.gd
##
## Genera la misma decoración que el juego, usando el pipeline procedural,
## pero la guarda como escena para que el juego no vuelva a calcularla.

const WorldBoundary := preload("res://features/world/zones/world_boundary.gd")
const ZoneCatalog := preload("res://data/zones/zone_catalog.gd")
const WorldLayout := preload("res://data/world/world_layout.tres")
const BakeSignature := preload("res://features/world/zones/world_decoration_bake_signature.gd")
const OUTPUT_PATH := "res://assets/maps/world/baked_world_decoration.scn"


func _init() -> void:
	# Al ejecutar un script de SceneTree Godot instancia los autoloads del
	# proyecto. El baker construye el mundo de forma aislada, así que ningún
	# autoload debe comenzar a streamear zonas en el frame de salida.
	for autoload in root.get_children():
		autoload.process_mode = Node.PROCESS_MODE_DISABLED
	call_deferred("_bake")


func _bake() -> void:
	print("[WorldDecorationBaker] Generando decoración horneada…")
	var boundary := WorldBoundary.new()
	# Fuerza la ruta procedural aunque ya exista un horneado previo.
	# El horneado sólo necesita la grilla y las mallas que se guardan. Las
	# paredes y los MultiMeshes de árboles son runtime-only (las posiciones se
	# guardan como metadato) y no se crean en este proceso headless.
	boundary.build(ZoneCatalog.new(), true, false, false)
	var decoration := boundary.get_node_or_null("AutoDecoration") as Node3D
	if decoration == null:
		push_error("WorldDecorationBaker: no se generó AutoDecoration.")
		boundary.free()
		quit(1)
		return
	boundary.remove_child(decoration)
	decoration.set_meta("tree_positions", boundary.decoration_tree_positions())
	decoration.set_meta("source_signature", BakeSignature.current(WorldLayout))
	_remove_runtime_multimeshes(decoration)
	_set_owner_recursive(decoration, decoration)
	var packed := PackedScene.new()
	var pack_error := packed.pack(decoration)
	if pack_error != OK:
		push_error("WorldDecorationBaker: no se pudo empaquetar (%s)." % pack_error)
		decoration.free()
		boundary.free()
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_error("WorldDecorationBaker: no se pudo guardar %s (%s)." % [OUTPUT_PATH, save_error])
		decoration.free()
		boundary.free()
		quit(1)
		return
	print("[WorldDecorationBaker] Listo: %s (%d posiciones de árboles)." % [OUTPUT_PATH, boundary.decoration_tree_positions().size()])
	# En este punto sólo quedan las mallas serializadas: las paredes y los
	# MultiMeshes de runtime no se crearon para el horneado.
	decoration.free()
	boundary.free()
	quit()


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _remove_runtime_multimeshes(root: Node) -> void:
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		node.get_parent().remove_child(node)
		node.free()
