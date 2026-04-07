extends CharacterBody3D

const SPEED        := 6.0
const GRAVITY      := 20.0
const ROTATE_SPEED := 12.0

var camera_rig: Node3D

func _ready() -> void:
	camera_rig = get_parent().get_node_or_null("CameraRig")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	)

	var direction := Vector3.ZERO
	if input.length() > 0.1 and camera_rig:
		var yaw: float = camera_rig.yaw
		direction = Vector3(
			sin(yaw) * input.y + cos(yaw) * input.x,
			0.0,
			cos(yaw) * input.y - sin(yaw) * input.x
		).normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	if direction.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), ROTATE_SPEED * delta)

	move_and_slide()
