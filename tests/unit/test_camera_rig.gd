extends GutTest

const CameraRigScript := preload("res://features/world/world_map/camera_rig.gd")
const CollisionLayers := preload("res://shared/world_collision_layers.gd")

var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child(_world)


func after_each() -> void:
	_world.free()


func _make_rig() -> Node3D:
	var party := Node3D.new()
	_world.add_child(party)
	var player := Node3D.new()
	player.name = "Player"
	party.add_child(player)
	var rig := Node3D.new()
	rig.set_script(CameraRigScript)
	rig.pitch = 0.0
	rig.distance = 6.0
	rig.collision_margin = 0.3
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	party.add_child(rig)
	return rig


func _wall(z: float, layer: int) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = layer
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 8.0, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(0.0, 1.5, z)
	_world.add_child(wall)
	return wall


func test_la_camara_queda_antes_de_una_pared_de_terreno() -> void:
	var rig := _make_rig()
	_wall(3.0, CollisionLayers.CAMERA_TERRAIN)
	await get_tree().physics_frame
	rig._process(0.016)
	var camera := rig.get_node("Camera3D") as Camera3D
	# La cara cercana de la pared queda en z=2.9; con margen 0.3 queda antes de 2.6.
	assert_lte(camera.global_position.z, 2.61)
	assert_gte(camera.global_position.z, rig.min_distance)


func test_una_pared_invisible_de_obstaculos_no_acerca_la_camara() -> void:
	var rig := _make_rig()
	_wall(3.0, CollisionLayers.OBSTACLES)
	await get_tree().physics_frame
	rig._process(0.016)
	var camera := rig.get_node("Camera3D") as Camera3D
	assert_almost_eq(camera.global_position.z, rig.distance, 0.01)
