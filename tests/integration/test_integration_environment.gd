extends GutTest

## Mantiene el comando de integración válido en headless: los tests que cargan
## el mundo 3D se omiten ahí, pero GUT necesita al menos un caso ejecutado.

func test_el_renderer_tiene_un_nombre() -> void:
	assert_ne(DisplayServer.get_name(), "")
