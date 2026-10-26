extends GutTest


func test_las_herramientas_de_desarrollo_no_son_estado_de_partida() -> void:
	var previous := DebugSettings.developer_tools_enabled
	DebugSettings.set_developer_tools_enabled(false)
	assert_false(DebugSettings.developer_tools_enabled)
	DebugSettings.set_developer_tools_enabled(previous)


func test_el_log_verboso_arranca_apagado_y_se_puede_cambiar() -> void:
	assert_false(DebugSettings.verbose_logging_enabled)
	DebugSettings.set_verbose_logging_enabled(true)
	assert_true(DebugSettings.verbose_logging_enabled)
	DebugSettings.set_verbose_logging_enabled(false)
