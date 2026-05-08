extends Node3D

@onready var menu: Control = $MenuLayer/MainMenu

var _ps1_shader := preload("res://features/world/world_map/ps1_vertex.gdshader")

func _ready() -> void:
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_clock_paused(false)
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
	PauseMenu.enabled = false
	_setup_environment()
	_setup_screen_fx()
	_build_floor_collision()
	_fix_map_vertex_colors()
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	PartyManager.place_at_spawn(self)

func _on_lab_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		get_tree().change_scene_to_file.call_deferred("res://features/world/lab_interior/lab_interior.tscn")

func _input(event: InputEvent) -> void:
	if _is_menu_pressed(event):
		_toggle_menu()
	elif _is_cancel_pressed(event) and menu.visible:
		_toggle_menu()

func _toggle_menu() -> void:
	var showing := not menu.visible
	menu.visible = showing
	GlobalHUD.set_clock_visible(false if showing else GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_clock_paused(showing)
	GlobalHUD.set_youns_status_visible(false if showing else GlobalHUD.has_persistent_care_ui())
	PartyManager.camera_rig.enabled = not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.85)
	env.fog_enabled = true
	env.fog_density = 0.015
	env.fog_light_color = Color(0.55, 0.65, 0.78)
	env.fog_light_energy = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.5)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _setup_screen_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://features/world/world_map/ps1_screen.gdshader")
	mat.set_shader_parameter("pixel_size", 2.0)
	rect.material = mat
	layer.add_child(rect)
	add_child(layer)

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

func _build_terrain() -> void:
	var body := StaticBody3D.new()

	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0
	mesh_inst.mesh = plane
	mesh_inst.material_override = _mat(Color(0.28, 0.45, 0.18))

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 0.1, 80)
	col.shape = shape

	body.add_child(mesh_inst)
	body.add_child(col)
	add_child(body)

func _build_world() -> void:
	# Edificios principales
	_building(Vector3(-12, 0, -10), Vector3(5, 6, 5), Color(0.45, 0.25, 0.7))   # Laboratorio
	_building(Vector3( 12, 0,  -8), Vector3(7, 4, 6), Color(0.2,  0.45, 0.7))   # Ciudad
	_building(Vector3(  0, 0,  14), Vector3(4, 8, 4), Color(0.6,  0.2,  0.2))   # Dungeon

	# Rocas decorativas
	_box(Vector3(-5, 0,  3), Vector3(1.2, 0.8, 1.0), Color(0.45, 0.42, 0.38))
	_box(Vector3( 3, 0,  6), Vector3(0.9, 0.6, 1.1), Color(0.42, 0.40, 0.36))
	_box(Vector3(-8, 0,  8), Vector3(1.5, 1.0, 1.2), Color(0.48, 0.44, 0.40))

	# Arboles
	_tree(Vector3(-6,  0,  5))
	_tree(Vector3( 6,  0,  4))
	_tree(Vector3(-14, 0,  3))
	_tree(Vector3( 14, 0,  3))
	_tree(Vector3( 0,  0, -5))
	_tree(Vector3(-3,  0, 10))
	_tree(Vector3( 5,  0, 10))

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

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos

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

func _tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos

	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.18
	cyl.bottom_radius = 0.22
	cyl.height        = 1.6
	trunk.mesh = cyl
	trunk.position.y  = 0.8
	trunk.material_override = _mat(Color(0.35, 0.22, 0.1))

	var top := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius    = 0.0
	cone.bottom_radius = 1.1
	cone.height        = 2.4
	top.mesh = cone
	top.position.y = 2.4
	top.material_override = _mat(Color(0.18, 0.42, 0.14))

	root.add_child(trunk)
	root.add_child(top)
	add_child(root)

func _mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _ps1_shader
	m.set_shader_parameter("albedo", color)
	return m

func _is_cancel_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _is_menu_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("menu_toggle"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _exit_tree() -> void:
	PauseMenu.enabled = false
