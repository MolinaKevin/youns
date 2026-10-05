extends Node3D

## Estación de guardado: junto con dormir, el único lugar donde se guarda la
## partida. Se arma sola (modelo PLACEHOLDER: pedestal y cristal flotante), así
## que alcanza con poner un nodo con este script en cualquier zona.

const INTERACT_RADIUS := 2.5
const CRYSTAL_COLOR := Color(0.35, 0.85, 1.0)

var _prompt: Label3D
var _crystal: MeshInstance3D
var _near := false
var _dialog: CanvasLayer = null
var _time := 0.0

func _ready() -> void:
	_build_model()
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = INTERACT_RADIUS
	col.shape = shape
	col.position.y = 1.0
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.name == "Player":
			_near = true
			_prompt.visible = _dialog == null)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.name == "Player":
			_near = false
			_prompt.visible = false)

	_prompt = Label3D.new()
	_prompt.position.y = 2.6
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.visible = false
	add_child(_prompt)
	LocalizationState.language_changed.connect(_apply_text)
	_apply_text()

func _build_model() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.45, 0.45, 0.5)
	var base := CylinderMesh.new()
	base.top_radius = 0.35
	base.bottom_radius = 0.5
	base.height = 0.9
	base.material = stone
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base
	base_mi.position.y = 0.45
	add_child(base_mi)

	var body := StaticBody3D.new()
	var body_col := CollisionShape3D.new()
	var body_shape := CylinderShape3D.new()
	body_shape.radius = 0.5
	body_shape.height = 0.9
	body_col.shape = body_shape
	body_col.position.y = 0.45
	body.add_child(body_col)
	add_child(body)

	var glow := StandardMaterial3D.new()
	glow.albedo_color = CRYSTAL_COLOR
	glow.emission_enabled = true
	glow.emission = CRYSTAL_COLOR
	glow.emission_energy_multiplier = 1.5
	var crystal := PrismMesh.new()
	crystal.size = Vector3(0.35, 0.5, 0.35)
	crystal.material = glow
	_crystal = MeshInstance3D.new()
	_crystal.mesh = crystal
	_crystal.position.y = 1.4
	add_child(_crystal)
	var bottom := MeshInstance3D.new()
	bottom.mesh = crystal
	bottom.rotation_degrees.x = 180.0
	bottom.position.y = -0.5
	_crystal.add_child(bottom)

	var light := OmniLight3D.new()
	light.light_color = CRYSTAL_COLOR
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 1.4
	add_child(light)

func _process(delta: float) -> void:
	_time += delta
	_crystal.rotation.y += delta * 1.2
	_crystal.position.y = 1.4 + sin(_time * 2.0) * 0.08

func _apply_text(_language: String = "") -> void:
	_prompt.text = LocalizationState.t("save_station.prompt")

func _unhandled_input(event: InputEvent) -> void:
	if not _near or _dialog != null:
		return
	if event.is_action_pressed("interact") and not (event is InputEventKey and event.echo):
		get_viewport().set_input_as_handled()
		_open_dialog()

# ── Diálogo "¿Guardar la partida?" ──────────────────────────────────────────

func _open_dialog() -> void:
	_prompt.visible = false
	_dialog = CanvasLayer.new()
	_dialog.layer = 80
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.border_color = CRYSTAL_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var message := Label.new()
	message.text = LocalizationState.t("save_station.question")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var yes := Button.new()
	yes.text = LocalizationState.t("sleep.yes")
	yes.pressed.connect(_on_save)
	buttons.add_child(yes)
	var no := Button.new()
	no.text = LocalizationState.t("sleep.no")
	no.pressed.connect(_close_dialog)
	buttons.add_child(no)
	# Esc también cierra.
	var cancel_catcher := _CancelCatcher.new()
	cancel_catcher.cancelled.connect(_close_dialog)
	_dialog.add_child(cancel_catcher)
	get_tree().root.add_child(_dialog)
	get_tree().paused = true
	GlobalHUD.set_clock_paused(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	yes.grab_focus()

func _on_save() -> void:
	GameState.save_player_save()
	GlobalHUD.show_toast(LocalizationState.t("game.saved"))
	_close_dialog()

func _close_dialog() -> void:
	if _dialog == null:
		return
	_dialog.queue_free()
	_dialog = null
	get_tree().paused = false
	GlobalHUD.set_clock_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_prompt.visible = _near

## Escucha Esc mientras el diálogo está abierto (con el juego pausado).
class _CancelCatcher extends Node:
	signal cancelled
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") and not (event is InputEventKey and event.echo):
			get_viewport().set_input_as_handled()
			cancelled.emit()
