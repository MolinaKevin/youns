class_name Ps1ScreenFx
extends RefCounted

## Pixelado PS1 que cubre toda la pantalla: una CanvasLayer con un ColorRect a
## pantalla completa y el shader ps1_screen. Estaba copiado tal cual en
## game_world.gd y world_map.gd.
static func attach(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://features/world/world_map/ps1_screen.gdshader")
	mat.set_shader_parameter("pixel_size", 2.0)
	rect.material = mat
	layer.add_child(rect)
	parent.add_child(layer)
