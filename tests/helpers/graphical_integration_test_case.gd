extends GutTest

## Base de los tests que cargan mapas y recursos 3D importados.
## El renderer dummy de Godot no puede crear esas mallas en headless.

func should_skip_script():
	if DisplayServer.get_name() == "headless":
		return "Requiere una sesión de Godot con renderer gráfico."
	return false
