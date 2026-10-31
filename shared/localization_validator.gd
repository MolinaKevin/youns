class_name LocalizationValidator
extends RefCounted

## Detecta claves literales usadas desde GDScript que faltan en alguna tabla.
## Las claves construidas dinámicamente quedan fuera: cada familia dinámica se
## valida desde los tests de datos que conocen su catálogo.

static func static_keys() -> PackedStringArray:
	var found := {}
	var pattern := RegEx.new()
	pattern.compile('LocalizationState\\.t\\("([^"]+)"')
	for root in ["res://autoload", "res://data", "res://features", "res://shared"]:
		_collect_keys(root, pattern, found)
	var keys := PackedStringArray()
	for key in found:
		# Familias como "combat.status_name.%s" se resuelven con datos de
		# runtime y se validan en sus pruebas de catálogo, no como clave literal.
		if "%" not in key and not str(key).ends_with("."):
			keys.append(key)
	keys.sort()
	return keys


static func missing_keys(translations: Dictionary, keys: PackedStringArray) -> PackedStringArray:
	var missing := PackedStringArray()
	for key in keys:
		if not translations.has(key):
			missing.append(key)
	return missing


static func family_keys(prefix: String, ids: Array) -> PackedStringArray:
	var keys := PackedStringArray()
	for id in ids:
		keys.append(prefix + str(id))
	return keys


static func _collect_keys(path: String, pattern: RegEx, found: Dictionary) -> void:
	for file_name in DirAccess.get_files_at(path):
		if not file_name.ends_with(".gd"):
			continue
		var file := FileAccess.open(path.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		for result in pattern.search_all(file.get_as_text()):
			found[result.get_string(1)] = true
	for directory in DirAccess.get_directories_at(path):
		_collect_keys(path.path_join(directory), pattern, found)
