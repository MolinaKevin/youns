extends Camera3D

@export var zoom_speed := 4.0
@export var pan_speed  := 0.08
@export var zoom_min   := 1.0
@export var zoom_max   := 80.0

@export var orbit_speed := 0.005

var _orbit_pivot := Vector3.ZERO
var _has_orbit_pivot := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(-1)
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_orbit_pivot = _ray_to_ground(event.position)
					_has_orbit_pivot = true
				else:
					_has_orbit_pivot = false

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_pan(event.relative)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_orbit(event.relative)

func _zoom(direction: int) -> void:
	var target  := _ray_to_ground(get_viewport().get_mouse_position())
	var to_target := target - global_position
	var new_pos   := global_position + to_target.normalized() * direction * zoom_speed
	new_pos.y     = clampf(new_pos.y, zoom_min, zoom_max)
	global_position = new_pos

func _ray_to_ground(screen_pos: Vector2) -> Vector3:
	var from := project_ray_origin(screen_pos)
	var dir  := project_ray_normal(screen_pos)
	if abs(dir.y) < 0.001:
		return global_position + (-global_basis.z) * 20.0
	var t := -from.y / dir.y
	if t < 0.0:
		return global_position + (-global_basis.z) * 20.0
	return from + dir * t

func _orbit(delta: Vector2) -> void:
	var pivot  := _orbit_pivot if _has_orbit_pivot else _ray_to_ground(get_viewport().get_mouse_position())
	var offset := global_position - pivot

	# Horizontal: rotar alrededor del eje Y
	offset = offset.rotated(Vector3.UP, -delta.x * orbit_speed)

	# Vertical: rotar alrededor del eje derecho de la cámara
	var right := global_basis.x
	var new_offset := offset.rotated(right, -delta.y * orbit_speed)

	# Evitar que la cámara pase por debajo del suelo
	if (pivot + new_offset).y >= zoom_min:
		offset = new_offset

	global_position = pivot + offset
	look_at(pivot, Vector3.UP)

func _process(delta: float) -> void:
	var right        := global_basis.x
	var forward_flat := -global_basis.z
	forward_flat.y   = 0.0
	if forward_flat.length() > 0.001:
		forward_flat = forward_flat.normalized()
	var speed := pan_speed * (global_position.y / 10.0) * 200.0 * delta
	var move  := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): move += forward_flat
	if Input.is_key_pressed(KEY_S): move -= forward_flat
	if Input.is_key_pressed(KEY_A): move -= right
	if Input.is_key_pressed(KEY_D): move += right
	if move.length() > 0.001:
		global_position += move.normalized() * speed

func _pan(delta: Vector2) -> void:
	var right        := global_basis.x
	var forward_flat := -global_basis.z
	forward_flat.y   = 0.0
	if forward_flat.length() > 0.001:
		forward_flat = forward_flat.normalized()
	var speed := pan_speed * (global_position.y / 10.0)
	global_position -= right        * delta.x * speed
	global_position += forward_flat * delta.y * speed
