extends GutTest


func test_las_herramientas_de_desarrollo_no_son_estado_de_partida() -> void:
	var previous := DebugSettings.developer_tools_enabled
	DebugSettings.set_developer_tools_enabled(false)
	assert_false(DebugSettings.developer_tools_enabled)
	DebugSettings.set_developer_tools_enabled(previous)
