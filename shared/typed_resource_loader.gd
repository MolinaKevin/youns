class_name TypedResourceLoader
extends RefCounted

## Punto único para cargar recursos persistidos o configurados por ruta. Las
## funciones devuelven null tanto para rutas inexistentes como para recursos de
## otro tipo, para que los llamadores no tengan que repetir ambos chequeos.

static func youn(path: String) -> YounData:
	return _load(path) as YounData


static func item(path: String) -> ItemData:
	return _load(path) as ItemData


static func packed_scene(path: String) -> PackedScene:
	return _load(path) as PackedScene


static func texture(path: String) -> Texture2D:
	return _load(path) as Texture2D


static func sprite_frames(path: String) -> SpriteFrames:
	return _load(path) as SpriteFrames


static func lab_recipe(path: String) -> LabRecipe:
	return _load(path) as LabRecipe


static func _load(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)
