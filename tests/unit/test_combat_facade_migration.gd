extends GutTest

## La fachada monolítica fue eliminada. Este chequeo evita que vuelva a entrar
## en código, escenas o documentación por una migración futura.
const _REMOVED_CLASS := "CombatMap" + "Interactions"
const _REMOVED_FILE := "combat_map_" + "interactions"
const _SCANNED_EXTENSIONS := ["gd", "md", "tscn", "tres", "yml", "yaml", "json"]

func test_no_quedan_referencias_a_la_fachada_eliminada() -> void:
	var matches: Array[String] = []
	_scan_directory("res://", matches)
	assert_true(matches.is_empty(), "No deben reaparecer referencias: %s" % ", ".join(matches))

func _scan_directory(path: String, matches: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry == "." or entry == ".." or entry == ".git" or entry == ".godot":
			entry = directory.get_next()
			continue
		var child_path := path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(child_path, matches)
		elif _is_scannable(entry):
			var contents := FileAccess.get_file_as_string(child_path)
			if contents.contains(_REMOVED_CLASS) or contents.contains(_REMOVED_FILE):
				matches.append(child_path)
		entry = directory.get_next()
	directory.list_dir_end()

func _is_scannable(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension in _SCANNED_EXTENSIONS
