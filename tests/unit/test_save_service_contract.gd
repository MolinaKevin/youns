extends GutTest

func test_los_consumidores_productivos_no_acceden_al_alias_de_game_state() -> void:
	var matches: Array[String] = []
	for root in ["res://autoload", "res://data", "res://features", "res://shared"]:
		_scan(root, matches)
	assert_true(matches.is_empty(), "Usar GameState.save_service.player_save: %s" % ", ".join(matches))


func _scan(path: String, matches: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = directory.get_next()
			continue
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_scan(child, matches)
		elif entry.get_extension().to_lower() == "gd" and entry != "game_state.gd":
			var contents := FileAccess.get_file_as_string(child)
			if contents.contains("GameState.player_save"):
				matches.append(child)
		entry = directory.get_next()
	directory.list_dir_end()
