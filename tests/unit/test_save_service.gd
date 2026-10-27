extends GutTest

var _service: SaveService


func before_each() -> void:
	_service = SaveService.new()


func test_partida_nueva_usa_la_version_actual() -> void:
	var save := _service.make_new_save(8.0)

	assert_eq(save.save_version, SaveService.CURRENT_SAVE_VERSION)


func test_partida_legacy_se_migra_y_conserva_su_progreso() -> void:
	var legacy := PlayerSaveData.new()
	legacy.current_youn_path = SaveService.STARTING_YOUN_PATH
	legacy.save_version = 0
	legacy.gold = 321
	legacy.youn_stats = {"vitalidad": 44, "fuerza": 61}
	legacy.youn_stat_gains = {"energia": 7}
	legacy.world_progress = null
	_service.migrate_save(legacy)
	var migrated := legacy

	assert_not_null(migrated)
	assert_eq(migrated.save_version, SaveService.CURRENT_SAVE_VERSION)
	assert_eq(migrated.gold, 321)
	assert_eq(migrated.youn_stats["constitucion"], 44)
	assert_eq(migrated.youn_stats["fuerza"], 61)
	assert_eq(migrated.youn_stat_gains["mente"], 7)
	assert_not_null(migrated.world_progress)


func test_migrar_dos_veces_no_duplica_las_estadisticas() -> void:
	var save := PlayerSaveData.new()
	save.youn_stats = {"vitalidad": 44}

	_service.migrate_save(save)
	_service.migrate_save(save)

	assert_eq(save.youn_stats, {"constitucion": 44})
	assert_eq(save.save_version, SaveService.CURRENT_SAVE_VERSION)


func test_migrar_v1_con_puente_construido_conserva_el_acceso() -> void:
	var save := PlayerSaveData.new()
	save.save_version = 1
	save.completed_recipe_ids = ["construccion_de_puente"]

	_service.migrate_save(save)

	assert_true(save.world_progress.has_bridge("river_bridge"))


func test_migrar_v2_con_puente_guardado_lo_pasa_a_construcciones() -> void:
	var save := PlayerSaveData.new()
	save.save_version = 2
	save.world_progress.unlocked_bridge_ids = ["river_bridge"]

	_service.migrate_save(save)

	assert_true(save.world_progress.has_construction("river_bridge"))
	assert_true(save.world_progress.unlocked_bridge_ids.is_empty())


func test_migrar_v3_renombra_pombero_a_newen() -> void:
	var save := PlayerSaveData.new()
	save.save_version = 3
	save.current_youn_path = "res://data/youns/pombero.tres"
	save.pending_evolution_path = "res://data/youns/pombero.tres"
	save.discovered_evolutions = {"pombero": [1, 2]}

	_service.migrate_save(save)

	assert_eq(save.current_youn_path, "res://data/youns/newen.tres")
	assert_eq(save.pending_evolution_path, "res://data/youns/newen.tres")
	assert_eq(save.discovered_evolutions["newen"], [1, 2])
	assert_false(save.discovered_evolutions.has("pombero"))
