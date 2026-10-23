extends Node3D

const CollisionLayers := preload("res://shared/world_collision_layers.gd")

var target: Node3D
@export var target_offset := Vector3(0, 1.5, 0)
@export var distance := 6.0
@export var sensitivity := 0.003
@export var min_pitch := -0.2
@export var max_pitch := 1.1
## Separación entre la cámara y el terreno que intercepta el rayo.
@export var collision_margin := 0.3
## Distancia preferida mínima al pivote. Si una pared está aún más cerca, la
## colisión tiene prioridad para no mostrar el interior de la geometría.
@export var min_distance := 1.2
## Metros por segundo con los que vuelve a alejarse al desaparecer un obstáculo.
@export var return_speed := 8.0

var yaw := 0.0
var pitch := 0.45
var enabled := true
var _current_distance := -1.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	target = get_parent().get_node_or_null("Player")

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw   -= event.relative.x * sensitivity
		pitch  = clamp(pitch + event.relative.y * sensitivity, min_pitch, max_pitch)

func _process(delta: float) -> void:
	if not target:
		return
	var pivot := target.global_position + target_offset
	var direction := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	).normalized()
	var desired_position := pivot + direction * distance
	var safe_distance := _collision_safe_distance(pivot, desired_position)
	if _current_distance < 0.0:
		_current_distance = safe_distance
	elif safe_distance < _current_distance:
		# Acercarse es inmediato: evita un frame dentro de una montaña o cañón.
		_current_distance = safe_distance
	else:
		# Alejarse es suave para que al despegarse de una pared no dé un salto.
		_current_distance = move_toward(_current_distance, safe_distance, return_speed * delta)
	camera.global_position = pivot + direction * _current_distance
	camera.look_at(pivot, Vector3.UP)


func _collision_safe_distance(pivot: Vector3, desired_position: Vector3) -> float:
	# La máscara exclusiva evita que actores, WorldBoundary, GymForest, barandas
	# y demás *-colonly invisibles alteren la cámara.
	var query := PhysicsRayQueryParameters3D.create(
		pivot,
		desired_position,
		CollisionLayers.CAMERA_TERRAIN
	)
	query.exclude = [target.get_rid()] if target is CollisionObject3D else []
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return maxf(distance, min_distance)
	var hit_distance := pivot.distance_to(hit["position"] as Vector3)
	# Si una pared está dentro de min_distance se prioriza no atravesarla; en el
	# resto de casos se respeta la distancia mínima al jugador.
	return minf(distance, maxf(0.0, hit_distance - collision_margin)) if hit_distance < min_distance else maxf(min_distance, hit_distance - collision_margin)
