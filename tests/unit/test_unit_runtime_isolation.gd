extends GutTest

## Los unit tests no deben instanciar mapas ni streaming: además de ser mucho
## más lentos, el renderer dummy no puede construir todos los meshes del mundo.

func test_el_runner_unitario_no_inicializa_el_mundo_3d() -> void:
	await get_tree().process_frame
	assert_false(ZoneManager.is_world_initialized())
