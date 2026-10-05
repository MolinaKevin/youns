class_name ZoneBase
extends Node3D

# Lo asigna ZoneManager al instanciar la zona (clave en ZoneManager.ZONES).
# La zona actual la decide ZoneManager según dónde está parado el jugador; el
# nodo ZoneTrigger de las escenas ya no se usa.
var zone_id := ""

func _ready() -> void:
	pass

# Los .glb importados traen el color en los vértices; activarlo en sus materiales.
func _fix_map_vertex_colors(map_name: String) -> void:
	var map := get_node_or_null(map_name)
	if not map:
		return
	for node in map.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).vertex_color_use_as_albedo = true
