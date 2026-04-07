extends Node3D

var target: Node3D
@export var target_offset := Vector3(0, 1.5, 0)
@export var distance := 6.0
@export var sensitivity := 0.003
@export var min_pitch := -0.2
@export var max_pitch := 1.1

var yaw := 0.0
var pitch := 0.45
var enabled := true

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	target = get_parent().get_node_or_null("Player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw   -= event.relative.x * sensitivity
		pitch  = clamp(pitch + event.relative.y * sensitivity, min_pitch, max_pitch)

func _process(_delta: float) -> void:
	if not target:
		return
	var pivot := target.global_position + target_offset
	camera.global_position = pivot + Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * distance
	camera.look_at(pivot, Vector3.UP)
