extends GutTest

const _DIRECT_CARE := "StatsManager." + "care_service"
const _DIRECT_EMOTIONS := "StatsManager." + "emotion_service"
const _DIRECT_LIFE := "StatsManager." + "life_stage"

func test_stats_manager_expone_el_puerto_de_servicios() -> void:
	assert_is(StatsManager.services, StatsServicesAdapter)
	assert_eq(StatsManager.services.care(), StatsManager.care_service)
	assert_eq(StatsManager.services.emotions(), StatsManager.emotion_service)
	assert_eq(StatsManager.services.life(), StatsManager.life_stage)

func test_los_consumidores_productivos_no_acceden_a_fachadas_historicas() -> void:
	var matches: Array[String] = []
	for root in ["res://autoload", "res://data", "res://features", "res://shared"]:
		_scan(root, matches)
	assert_true(matches.is_empty(), "Usar StatsManager.services: %s" % ", ".join(matches))

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
		elif entry.get_extension().to_lower() == "gd" and entry != "stats_manager.gd":
			var contents := FileAccess.get_file_as_string(child)
			if contents.contains(_DIRECT_CARE) or contents.contains(_DIRECT_EMOTIONS) or contents.contains(_DIRECT_LIFE):
				matches.append(child)
		entry = directory.get_next()
	directory.list_dir_end()
