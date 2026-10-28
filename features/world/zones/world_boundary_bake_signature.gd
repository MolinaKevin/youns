class_name WorldBoundaryBakeSignature
extends RefCounted

## Extiende la firma de decoración con el constructor de paredes, cuya salida
## física también queda serializada en el horneado de límites.

const VERSION := 1
const DecorationSignature := preload("res://features/world/zones/world_decoration_bake_signature.gd")
const WALLS_PATH := "res://features/world/zones/world_boundary_walls.gd"


static func current(layout: WorldLayout) -> String:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	var walls_hash := FileAccess.get_sha256(WALLS_PATH) if FileAccess.file_exists(WALLS_PATH) else "MISSING"
	hasher.update(("%d:%s:%s" % [VERSION, DecorationSignature.current(layout), walls_hash]).to_utf8_buffer())
	return "%d:%s" % [VERSION, hasher.finish().hex_encode()]
