class_name UiAssetCache
extends RefCounted

static var _textures: Dictionary = {}
static var _scenes: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _textures.has(path):
		_textures[path] = TypedResourceLoader.texture(path)
	return _textures[path]

static func packed_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if not _scenes.has(path):
		_scenes[path] = TypedResourceLoader.packed_scene(path)
	return _scenes[path]
