extends CanvasLayer

## Menú de una estación del gimnasio: elegir el tipo de entrenamiento, pasar el
## tiempo con un fundido a negro y sumar la estadística de la estación.

const FADE_DURATION := 0.6

## Tipos de entrenamiento: id → horas que pasan y puntos que suma.
## Por ahora bonus es igual a normal (se va a diferenciar más adelante).
const TRAININGS := {
	"normal": {"hours": 1.0, "amount": 10},
	"bonus":  {"hours": 1.0, "amount": 10},
}

## Estadística que entrena esta estación (una de YounStats.KEYS).
var stat_key := ""

## Recorrido opcional en posiciones globales. Si tiene puntos, el Youn lo corre
## en vez del fundido directo (estación de Resistencia del gimnasio).
var circuit_points: Array[Vector3] = []
const RUN_SPEED := 7.0
## Fracción del recorrido en la que se hace el fundido (el Youn ya está en el bosque).
const CIRCUIT_FADE_AT := 0.45

var _fade: ColorRect
var _panel: PanelContainer
var _title: Label
var _normal_btn: Button
var _bonus_btn: Button
var _cancel_btn: Button
var _busy := false
var _world_lease: WorldTransitionLease
var _flow: AsyncFlowToken


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_apply_text()
	LocalizationState.language_changed.connect(_apply_text)
	_world_lease = WorldTransitionLease.new(ModalScreenHost.from_runtime(), PartyManager)
	_flow = AsyncFlowToken.new(self)
	_normal_btn.grab_focus()


func _build_ui() -> void:
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	var centering := CenterContainer.new()
	centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centering)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	centering.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title)

	_normal_btn = Button.new()
	_normal_btn.pressed.connect(_train.bind("normal"))
	vbox.add_child(_normal_btn)

	_bonus_btn = Button.new()
	_bonus_btn.pressed.connect(_train.bind("bonus"))
	vbox.add_child(_bonus_btn)

	_cancel_btn = Button.new()
	_cancel_btn.pressed.connect(_close)
	vbox.add_child(_cancel_btn)


func _apply_text(_lang: String = "") -> void:
	_title.text = LocalizationState.t("gym.title", [_stat_name()])
	_normal_btn.text = LocalizationState.t("gym.option.normal", [TRAININGS["normal"]["amount"], int(TRAININGS["normal"]["hours"])])
	_bonus_btn.text = LocalizationState.t("gym.option.bonus", [TRAININGS["bonus"]["amount"], int(TRAININGS["bonus"]["hours"])])
	_cancel_btn.text = LocalizationState.t("gym.option.cancel")


func _stat_name() -> String:
	return LocalizationState.t("youn_stat." + stat_key)


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()
		return
	if InputPresses.is_cancel_pressed(event):
		get_viewport().set_input_as_handled()
		_close()


func _train(training_id: String) -> void:
	if _busy:
		return
	_busy = true
	_panel.visible = false
	var training: Dictionary = TRAININGS[training_id]
	if circuit_points.size() >= 2 and is_instance_valid(PartyManager.youn):
		_run_circuit(training)
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(_apply_training.bind(training))
	tween.tween_interval(0.3)
	tween.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	tween.tween_callback(_close)


## Pasa el tiempo y suma la estadística (con los potenciadores del laboratorio).
func _apply_training(training: Dictionary) -> void:
	var save := PlayerSessionAccess.save()
	var hours: float = training["hours"]
	var amount: int = training["amount"]
	if save and save.training_time_compression_pending:
		hours *= 0.5
		save.training_time_compression_pending = false
	if save and save.training_progress_boost_pending:
		amount = roundi(float(amount) * 1.5)
		save.training_progress_boost_pending = false
	GameState.advance_hours(hours)
	if save:
		YounStatRules.reward(save, {stat_key: amount}, _party_youn_data())
	GlobalHUD.show_toast(LocalizationState.t("gym.result", [_stat_name(), amount]))


## Estación con recorrido (Resistencia): el Youn corre por el circuito del
## bosque; cuando está adentro, fundido a negro y pasa el tiempo; después vuelve
## corriendo por el resto del recorrido. El jugador se queda esperando.
func _run_circuit(training: Dictionary) -> void:
	var youn = PartyManager.youn
	var cam = PartyManager.camera_rig
	var previous_target: Node3D = cam.target if cam else null
	if cam:
		cam.target = youn
	var y: float = youn.global_position.y
	var points: Array[Vector3] = [youn.global_position]
	for p in circuit_points:
		points.append(Vector3(p.x, y, p.z))
	var split := clampi(int(points.size() * CIRCUIT_FADE_AT), 1, points.size() - 1)
	youn.play_anim("run")
	await _run_through(youn, points.slice(0, split + 1))
	if not _flow.is_active():
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_DURATION)
	tween.tween_callback(_apply_training.bind(training))
	tween.tween_interval(0.3)
	tween.tween_property(_fade, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	if not _flow.is_active():
		return
	await _run_through(youn, points.slice(split))
	if not _flow.is_active():
		return
	if is_instance_valid(youn):
		youn.play_anim("idle")
	if cam:
		cam.target = previous_target if is_instance_valid(previous_target) else PartyManager.player
	_close()


func _run_through(youn: Node3D, points: Array) -> void:
	for i in range(1, points.size()):
		if not is_instance_valid(youn):
			return
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var dist := a.distance_to(b)
		if dist < 0.05:
			continue
		youn.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var tween := create_tween()
		tween.tween_property(youn, "global_position", b, dist / RUN_SPEED)
		await tween.finished
		if not _flow.is_active():
			return


func _party_youn_data() -> YounData:
	var youn = PartyManager.youn if PartyManager else null
	return youn.youn_data if is_instance_valid(youn) else null


func _close() -> void:
	if _world_lease:
		_world_lease.release()
	queue_free()


func _exit_tree() -> void:
	if _flow:
		_flow.cancel()
	if is_instance_valid(PartyManager.youn):
		PartyManager.youn.play_anim("idle")
	if is_instance_valid(PartyManager.camera_rig):
		PartyManager.camera_rig.target = PartyManager.player
	if _world_lease:
		_world_lease.release()
