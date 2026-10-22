extends CharacterBody3D

## Velocidad de desplazamiento normal y multiplicador al mantener Shift.
const SPEED        := 7.0
const SPRINT_MULTIPLIER := 1.4
const GRAVITY      := 20.0
const ROTATE_SPEED := 12.0

var camera_rig: Node3D
## Modelo con animaciones (player_model.gd); puede faltar en escenas viejas.
var _model: Node3D
## Bloquea el movimiento horizontal sin tocar set_physics_process(), así la
## gravedad sigue actuando (p.ej. cutscenes donde el jugador tiene que caer).
var movement_locked := false


func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint")


func movement_speed() -> float:
	return SPEED * (SPRINT_MULTIPLIER if is_sprinting() else 1.0)

func _ready() -> void:
	camera_rig = get_parent().get_node_or_null("CameraRig")
	_model = get_node_or_null("Body")
	if _model != null and not _model.has_method("set_base"):
		_model = null

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Vector2.ZERO
	if not movement_locked:
		input = Vector2(
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

	var speed := movement_speed()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if direction.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), ROTATE_SPEED * delta)
	if _model:
		_model.set_base("run" if direction.length() > 0.1 else "idle")

	move_and_slide()


## Animación de base del modelo (idle, walk, run). Para escenas con el
## movimiento frenado (set_physics_process(false)).
func set_anim_base(anim_name: String) -> void:
	if _model:
		_model.set_base(anim_name)


## Juega una acción del modelo (happy, angry, item_give…). Devuelve cuánto dura.
func play_action(anim_name: String) -> float:
	return _model.play_action(anim_name) if _model else 0.0


func stop_action() -> void:
	if _model:
		_model.stop_action()
