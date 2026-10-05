extends Node

## Muerte y reencarnación (la arranca game_world con
## StatsManager.reincarnation_triggered):
##   1. El Youn le llama la atención al jugador ("!") y se le acerca.
##   2. El jugador lo mira, confundido ("?"): "¿Quieres que elija una carta?".
##   3. Elige una carta del mazo (sin saber para qué). El Youn muere.
##   4. Elige un huevo (4 a la vista; en el demo solo uno se puede elegir).
##   5. Nace el bebé, con la carta heredada (StatsManager.complete_reincarnation).
##      La primera vez se desbloquea el listado de cartas reencarnadas.
## Si muere por salud en 0 (ReincarnationRules.CAUSE_HEALTH) no hay carta: el
## Youn está muy débil, se va, el jugador pierde una vida (se muestran las vidas
## solo acá) y elige el huevo.
## Todo pasa con el juego pausado: ningún enemigo interrumpe.

signal finished

const CARD_SCENE := preload("res://features/cards/presentation/card_view.tscn")
const CARD_SIZE := Vector2(195, 293)
const GRID_SCALE := 0.6
const PANEL_BG := Color(0.04, 0.09, 0.14, 0.97)
const BORDER := Color(0.35, 0.85, 1.0)
const GOLD := Color(1.0, 0.85, 0.35)

var _from: YounData
var _cause := ReincarnationRules.CAUSE_AGE
var _ui: CanvasLayer
var _flash: ColorRect
var _camera: Camera3D
var _previous_camera: Camera3D
var _marks: Array[Node] = []

func setup(from_data: YounData, cause := ReincarnationRules.CAUSE_AGE) -> void:
	_from = from_data
	_cause = cause

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = CanvasLayer.new()
	_ui.layer = 85
	add_child(_ui)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_flash)
	_run.call_deferred()

func _run() -> void:
	var player := PartyManager.player
	var youn := PartyManager.youn
	var youn_name := _from.youn_name if _from != null else "?"
	get_tree().paused = true
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_youns_status_visible(false)
	PartyManager.camera_rig.enabled = false

	# 1. Te llama la atención: se acerca y aparece un "!".
	var toward := player.global_transform.basis.z
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else Vector3.FORWARD
	var youn_spot := player.global_position + toward * 1.8
	youn_spot.y = youn.global_position.y
	_frame_camera(player.global_position, youn_spot)
	var by_health := _cause == ReincarnationRules.CAUSE_HEALTH
	var card: CardData = null
	if by_health:
		# Muy débil: se acerca despacio, sin carta.
		await _tween(youn, "global_position", youn_spot, 1.6)
		_face(youn, player.global_position)
		await _message(LocalizationState.t("reincarnation.weak", [youn_name]))
	else:
		var bang := _mark(youn, "!", 1.6)
		await _tween(youn, "global_position", youn_spot, 0.8)
		_face(youn, player.global_position)
		await _bounce(bang)

		# 2. El jugador lo mira, confundido.
		var target_rot := _yaw_toward(player.global_position, youn.global_position)
		await _tween(player, "rotation:y", lerp_angle(player.rotation.y, target_rot, 1.0), 0.5)
		var question := _mark(player, "?", 2.3)
		await _bounce(question)
		await _message(LocalizationState.t("reincarnation.look"))

		# 3. Elige una carta. El Youn muere.
		card = await _choose_card()
		_clear_marks()
	await _tween(_flash, "color:a", 1.0, 0.6)
	youn.visible = false
	await _tween(_flash, "color:a", 0.0, 0.6)
	await _message(LocalizationState.t("reincarnation.gone", [youn_name]))
	if by_health:
		# Las vidas solo se ven acá. Se descuentan al nacer el bebé.
		var lives := maxi(0, GameState.player_save.lives - 1)
		await _message(LocalizationState.t("reincarnation.life_lost"), _hearts(lives, ReincarnationRules.MAX_LIVES))

	# 4. Elige un huevo.
	var baby: YounData = await _choose_egg(card)

	# 5. Nace el bebé con la carta.
	await _tween(_flash, "color:a", 1.0, 0.4)
	if youn.has_method("load_youn"):
		youn.load_youn(baby)
	youn.global_position = youn_spot
	_face(youn, player.global_position)
	youn.visible = true
	await _tween(_flash, "color:a", 0.0, 0.8)
	var first_unlock := not GameState.player_save.reincarnated_cards_unlocked
	if card != null:
		var card_name := LocalizationState.card_name(card.id, card.name)
		await _message(LocalizationState.t("reincarnation.born", [baby.youn_name, card_name]))
	else:
		await _message(LocalizationState.t("reincarnation.born_no_card", [baby.youn_name]))
	StatsManager.complete_reincarnation(baby, card)
	if first_unlock and GameState.player_save.reincarnated_cards_unlocked:
		await _message(LocalizationState.t("reincarnation.cards_unlocked"))
	_finish()

func _finish() -> void:
	if _camera:
		_camera.queue_free()
	if is_instance_valid(_previous_camera):
		_previous_camera.current = true
	get_tree().paused = false
	PartyManager.camera_rig.enabled = true
	PartyManager.player.set_physics_process(true)
	PartyManager.youn.set_physics_process(true)
	GlobalHUD.set_clock_paused(false)
	GlobalHUD.set_clock_visible(GlobalHUD.has_persistent_clock_ui())
	GlobalHUD.set_youns_status_visible(GlobalHUD.has_persistent_care_ui())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()
	queue_free()

# ── Escena ───────────────────────────────────────────────────────────────────

## Cámara de costado que encuadra a los dos.
func _frame_camera(a: Vector3, b: Vector3) -> void:
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	add_child(_camera)
	var mid := (a + b) * 0.5
	var along := (b - a)
	along.y = 0.0
	var side := along.cross(Vector3.UP).normalized() if along.length() > 0.1 else Vector3.RIGHT
	_camera.global_position = mid + side * 4.5 + Vector3.UP * 2.2
	_camera.look_at(mid + Vector3.UP * 0.8)
	_camera.current = true

func _mark(node: Node3D, text: String, height: float) -> Label3D:
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

func _clear_marks() -> void:
	for mark in _marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()

func _bounce(label: Label3D) -> void:
	var base := label.position.y
	var tw := create_tween()
	for i in 2:
		tw.tween_property(label, "position:y", base + 0.25, 0.18)
		tw.tween_property(label, "position:y", base, 0.18)
	tw.tween_interval(0.5)
	await tw.finished

func _tween(node: Object, property: String, value: Variant, duration: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, property, value, duration)
	await tw.finished

func _face(node: Node3D, target: Vector3) -> void:
	node.rotation.y = _yaw_toward(node.global_position, target)

func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.05 else 0.0

# ── Interfaz ─────────────────────────────────────────────────────────────────

func _panel(min_width: float) -> Array:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	_ui.move_child(_flash, -1)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	return [root, column]

func _label(text: String, size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label

## Un mensaje con "Continuar" (y opcionalmente algo debajo del texto).
func _message(text: String, extra: Control = null) -> void:
	var parts := _panel(460)
	var column: VBoxContainer = parts[1]
	column.add_child(_label(text))
	if extra != null:
		column.add_child(extra)
	var ok := Button.new()
	ok.text = LocalizationState.t("reincarnation.continue")
	ok.custom_minimum_size = Vector2(0, 44)
	column.add_child(ok)
	ok.grab_focus()
	await ok.pressed
	parts[0].queue_free()

## Fila de corazones: llenos los que quedan, apagados los perdidos.
func _hearts(filled: int, total: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in total:
		var heart := _Heart.new()
		heart.filled = i < filled
		row.add_child(heart)
	return row

## Un corazón dibujado (la fuente no tiene ♥).
class _Heart extends Control:
	var filled := true
	func _init() -> void:
		custom_minimum_size = Vector2(34, 30)
	func _draw() -> void:
		var color := Color(0.9, 0.2, 0.3) if filled else Color(0.3, 0.3, 0.35)
		var r := 8.5
		draw_circle(Vector2(8.5, 9), r, color)
		draw_circle(Vector2(25.5, 9), r, color)
		draw_colored_polygon(PackedVector2Array([Vector2(0.6, 11), Vector2(33.4, 11), Vector2(17, 29)]), color)

## El mazo del Youn: el jugador elige una carta (la que va a heredar el huevo,
## aunque no se le dice).
func _choose_card() -> CardData:
	var parts := _panel(900)
	var column: VBoxContainer = parts[1]
	column.add_child(_label(LocalizationState.t("reincarnation.choose_card"), 22))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var confirm := Button.new()
	confirm.text = LocalizationState.t("reincarnation.choose")
	confirm.custom_minimum_size = Vector2(0, 44)
	confirm.disabled = true
	var selected: Array = [null]
	var views: Array = []
	for card in DeckRules.cards(GameState.player_save):
		var holder := Control.new()
		holder.custom_minimum_size = CARD_SIZE * GRID_SCALE
		grid.add_child(holder)
		var view = CARD_SCENE.instantiate()
		view.hover_enabled = false
		view.scale = Vector2.ONE * GRID_SCALE
		holder.add_child(view)
		view.setup(card)
		views.append(view)
		view.card_pressed.connect(func(c: CardData) -> void:
			selected[0] = c
			confirm.disabled = false
			for v in views:
				v.modulate = Color.WHITE if v.card_data == c else Color(1, 1, 1, 0.45))
	column.add_child(confirm)
	await confirm.pressed
	parts[0].queue_free()
	return selected[0]

## Los huevos: solo se pueden elegir los que tienen un bebé (ver
## ReincarnationRules.EGGS). Muestra la carta con la que viene.
func _choose_egg(card: CardData) -> YounData:
	var parts := _panel(640)
	var column: VBoxContainer = parts[1]
	column.add_child(_label(LocalizationState.t("reincarnation.choose_egg"), 24))
	var eggs := HBoxContainer.new()
	eggs.alignment = BoxContainer.ALIGNMENT_CENTER
	eggs.add_theme_constant_override("separation", 22)
	column.add_child(eggs)
	var chosen: Array = [null]
	var picked := Button.new()
	picked.visible = false
	for egg in ReincarnationRules.EGGS:
		var available := ReincarnationRules.egg_available(egg)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 150)
		b.disabled = not available
		b.text = "" if available else "?"
		b.add_theme_font_size_override("font_size", 40)
		var color: Color = egg["color"] if available else Color(0.3, 0.32, 0.35)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = color.lightened(0.15) if state == "hover" else color
			st.set_corner_radius_all(55)
			st.corner_radius_top_left = 55
			st.corner_radius_top_right = 55
			st.corner_radius_bottom_left = 48
			st.corner_radius_bottom_right = 48
			if state in ["hover", "focus"]:
				st.border_color = Color.WHITE
				st.set_border_width_all(3)
			b.add_theme_stylebox_override(state, st)
		if available:
			b.pressed.connect(func() -> void:
				chosen[0] = load(egg["youn"]) as YounData
				picked.pressed.emit())
		eggs.add_child(b)
	if card != null:
		column.add_child(_label(LocalizationState.t("reincarnation.egg_card"), 16))
		var center := CenterContainer.new()
		column.add_child(center)
		var holder := Control.new()
		holder.custom_minimum_size = CARD_SIZE * GRID_SCALE
		center.add_child(holder)
		var view = CARD_SCENE.instantiate()
		view.hover_enabled = false
		view.scale = Vector2.ONE * GRID_SCALE
		holder.add_child(view)
		view.setup(card)
		view.set_disabled(true)
	column.add_child(picked)
	await picked.pressed
	parts[0].queue_free()
	return chosen[0]
