extends Node3D

var zone_id := "hub"

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	_build_floor_collision()
	_fix_map_vertex_colors()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_zone(zone_id)

func _on_lab_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_interior("res://features/world/lab_interior/lab_interior.tscn")

func _fix_map_vertex_colors() -> void:
	var city_map := get_node_or_null("CityMap")
	if not city_map:
		return
	for node in city_map.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(i)
			if mat == null:
				mat = mi.mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).vertex_color_use_as_albedo = true

func _build_floor_collision() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 0.1, 200)
	col.shape = shape
	col.position.y = -0.05
	body.add_child(col)
	add_child(body)
