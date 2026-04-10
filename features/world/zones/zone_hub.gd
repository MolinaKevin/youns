extends Node3D

var zone_id := "hub"
var _ps1_shader := preload("res://features/world/world_map/ps1_vertex.gdshader")

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	_build_floor_collision()
	_fix_map_vertex_colors()
	_building(Vector3(18, 0, -18), Vector3(6, 5, 4), Color(0.9, 0.88, 0.85), deg_to_rad(135))

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

func _building(pos: Vector3, size: Vector3, color: Color, rot_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_inst.mesh = box
	mesh_inst.position.y = size.y / 2.0
	mesh_inst.material_override = _mat(color)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y / 2.0
	body.add_child(mesh_inst)
	body.add_child(col)
	add_child(body)

func _mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _ps1_shader
	m.set_shader_parameter("albedo", color)
	return m
