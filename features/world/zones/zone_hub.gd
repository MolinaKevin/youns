extends Node3D

var zone_id := "hub"
var _near_demo_monzaemon := false

func _ready() -> void:
	$ZoneTrigger.body_entered.connect(_on_body_entered)
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	$DemoMonzaemon/InteractArea.body_entered.connect(_on_demo_monzaemon_entered)
	$DemoMonzaemon/InteractArea.body_exited.connect(_on_demo_monzaemon_exited)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	_build_floor_collision()
	_fix_map_vertex_colors()
	_refresh_demo_bridge_visibility()

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_zone(zone_id)

func _on_lab_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_interior("res://features/world/lab_interior/lab_interior.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if _is_cancel_pressed(event) and $DemoDialog.visible:
		get_viewport().set_input_as_handled()
		_set_demo_dialog_visible(false)
		return
	if _near_demo_monzaemon and _is_interact_pressed(event):
		get_viewport().set_input_as_handled()
		_set_demo_dialog_visible(true)

func _on_demo_monzaemon_entered(body: Node3D) -> void:
	if body.name != "Player" or not $DemoRamp.visible:
		return
	_near_demo_monzaemon = true
	$DemoMonzaemon/Prompt.visible = true

func _on_demo_monzaemon_exited(body: Node3D) -> void:
	if body.name != "Player":
		return
	_near_demo_monzaemon = false
	$DemoMonzaemon/Prompt.visible = false
	_set_demo_dialog_visible(false)

func _set_demo_dialog_visible(showing: bool) -> void:
	$DemoDialog.visible = showing
	$DemoMonzaemon/Prompt.visible = _near_demo_monzaemon and not showing
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if showing else Input.MOUSE_MODE_CAPTURED

func _on_recipe_completed(recipe: Resource) -> void:
	if recipe.id == "estudio_de_puente_ligero" or recipe.id == "construccion_de_puente":
		_refresh_demo_bridge_visibility()

func _refresh_demo_bridge_visibility() -> void:
	var bridge_researched := LaboratoryState.is_recipe_completed("estudio_de_puente_ligero") \
		or LaboratoryState.is_recipe_completed("construccion_de_puente")
	$DemoRamp.visible = bridge_researched
	$DemoMonzaemon.visible = bridge_researched
	if not bridge_researched:
		_near_demo_monzaemon = false
		_set_demo_dialog_visible(false)

func _is_cancel_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

func _is_interact_pressed(event: InputEvent) -> bool:
	if not event.is_action_pressed("interact"):
		return false
	if event is InputEventKey:
		return not event.echo
	return true

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
