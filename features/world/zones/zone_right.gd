extends Node3D

var zone_id := "right"

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)
	_fix_map_vertex_colors()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_zone(zone_id)

func _fix_map_vertex_colors() -> void:
	var map := get_node_or_null("PraderaDerecha")
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
