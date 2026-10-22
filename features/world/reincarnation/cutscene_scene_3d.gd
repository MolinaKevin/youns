class_name CutsceneScene3D
extends RefCounted

## Helpers 3D genéricos para cutscenes con personajes: encuadre de cámara,
## marcas flotantes ("!", "?"), tweens cortos y orientación. `host` es el Node
## dueño exclusivo de esta instancia (necesita create_tween()/add_child()/
## get_viewport(), todos propios de Node).

const GOLD := Color(1.0, 0.85, 0.35)

var host
var camera: Camera3D
var previous_camera: Camera3D
var _marks: Array[Node] = []

func _init(p_host) -> void:
	host = p_host

## Cámara de costado que encuadra a los dos.
func frame_camera(a: Vector3, b: Vector3) -> void:
	previous_camera = host.get_viewport().get_camera_3d()
	camera = Camera3D.new()
	host.add_child(camera)
	var mid := (a + b) * 0.5
	var along := (b - a)
	along.y = 0.0
	var side := along.cross(Vector3.UP).normalized() if along.length() > 0.1 else Vector3.RIGHT
	camera.global_position = mid + side * 4.5 + Vector3.UP * 2.2
	camera.look_at(mid + Vector3.UP * 0.8)
	camera.current = true

func mark(node: Node3D, text: String, height: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.outline_size = 16
	label.modulate = GOLD
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = height
	node.add_child(label)
	_marks.append(label)
	return label

func clear_marks() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()

func bounce(label: Label3D) -> void:
	var base := label.position.y
	var tw: Tween = host.create_tween()
	for i in 2:
		tw.tween_property(label, "position:y", base + 0.25, 0.18)
		tw.tween_property(label, "position:y", base, 0.18)
	tw.tween_interval(0.5)
	await tw.finished

func tween(node: Object, property: String, value: Variant, duration: float) -> void:
	var tw: Tween = host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, property, value, duration)
	await tw.finished

func face(node: Node3D, target: Vector3) -> void:
	node.rotation.y = yaw_toward(node.global_position, target)

func yaw_toward(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.05 else 0.0

## Limpieza de la cámara de la escena al terminar (ver host._finish()).
func finish_camera() -> void:
	if camera:
		camera.queue_free()
	if is_instance_valid(previous_camera):
		previous_camera.current = true
