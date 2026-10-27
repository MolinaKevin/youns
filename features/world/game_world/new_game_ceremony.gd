class_name NewGameCeremony
extends Node3D

## Escena autónoma que antecede al mundo: sólo Pachamama, iluminación tenue y
## fondo negro. No instancia zonas ni el tutorial para que la apertura no deje
## el mapa visible detrás del diálogo.

const PACHAMAMA_PATH := "res://data/youns/pachamama.tres"
const WORLD_LOADING := "res://features/world/game_world/world_loading.tscn"
const NEWEN_PATH := "res://data/youns/newen.tres"
const NGURUVILU_PATH := "res://data/youns/nguruvilu.tres"
const ENTRANCE_SECONDS := 6.5
const WALK_ANIMATION_SPEED := 0.55
const MODEL_SCALE_MULTIPLIER := 1.45
const MODEL_HEIGHT_OFFSET := 0.8

var _data: YounData
var _model: Node3D
var _sequence_completed := false
var _entering_world := false
var _player_name := "Viajero"
var _companion_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[NewGameCeremony:%s] _ready: aislando la escena." % get_instance_id())
	# ZoneManager y PartyManager son autoloads: pueden conservar nodos y una
	# cámara de una sesión anterior. La ceremonia debe aislarse por completo.
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	_data = load(PACHAMAMA_PATH) as YounData
	if _data == null:
		push_error("[NewGameCeremony:%s] No se pudo cargar Pachamama." % get_instance_id())
		return
	print("[NewGameCeremony:%s] Pachamama cargada: id=%s." % [get_instance_id(), _data.id])
	_build_black_stage()
	print("[NewGameCeremony:%s] Escenario negro, cámara y modelo construidos; difiriendo secuencia." % get_instance_id())
	_run.call_deferred()


func _build_black_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.16, 0.16, 0.2, 1.0)
	environment.ambient_light_energy = 0.35
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.45, 6.4)
	camera.fov = 31.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	camera.make_current()

	var light := OmniLight3D.new()
	light.position = Vector3(-1.8, 3.8, 3.0)
	light.light_color = Color(0.84, 0.75, 1.0, 1.0)
	light.light_energy = 4.5
	light.omni_range = 12.0
	add_child(light)

	_model = _instantiate_model(
		_data.scene_walk if _data.scene_walk != null else _data.scene_idle,
		WALK_ANIMATION_SPEED
	)
	if _model == null:
		return
	_model.position = Vector3(4.0, _data.mesh_y_offset + MODEL_HEIGHT_OFFSET, 0.0)
	# El FBX tiene su frente invertido respecto del eje visual: -π/2 lo hace
	# entrar mirando hacia la izquierda de la pantalla.
	_model.rotation.y = -PI * 0.5
	add_child(_model)


func _instantiate_model(scene: PackedScene, animation_speed := 1.0) -> Node3D:
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	model.scale = Vector3.ONE * _data.mesh_scale * MODEL_SCALE_MULTIPLIER
	if _data.texture != null:
		var material := StandardMaterial3D.new()
		material.albedo_texture = _data.texture
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for mesh in Node3DSearch.find_meshes(model):
			mesh.material_override = material
	var animation_player := Node3DSearch.find_anim_player(model)
	if animation_player != null:
		animation_player.speed_scale = animation_speed
		var animations := animation_player.get_animation_list()
		if not animations.is_empty():
			var animation := animation_player.get_animation(animations[0])
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
			animation_player.play(animations[0])
	return model


func _run() -> void:
	print("[NewGameCeremony:%s] Inicio de secuencia; Pachamama entra en escena." % get_instance_id())
	if _model != null:
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_model, "position:x", 0.0, ENTRANCE_SECONDS)
		await tween.finished
		_settle_facing_camera()
	print("[NewGameCeremony:%s] Entrada terminada; primer diálogo." % get_instance_id())
	await _say(["Detenete un momento, viajero.", "Antes de que des tu primer paso, quiero conocerte."])
	print("[NewGameCeremony:%s] Primer diálogo terminado; pregunta 1." % get_instance_id())
	var has_youn := await _ask("¿Venís acompañado por un Youn?", ["Sí.", "No."])
	var partner_choice := 0
	if has_youn == 0:
		partner_choice = await _ask("¿Te guía más el amanecer o la noche?", ["El amanecer.", "La noche."])
	else:
		partner_choice = await _ask("¿Caminás entre muchos vínculos o por tu propia senda?", ["Entre muchos vínculos.", "Por mi propia senda."])
	_apply_starting_youn(NEWEN_PATH if partner_choice == 0 else NGURUVILU_PATH)
	_player_name = await _ask_name("Decime tu nombre.", "Viajero")
	_companion_name = await _ask_name("¿Cómo llamarás a tu compañero?", _starting_youn_name())
	_save_ceremony_names()
	await _say(["Entonces, %s, este será el comienzo de tu camino junto a %s." % [_player_name, _companion_name]])
	print("[NewGameCeremony:%s] Preguntas y nombres terminados; despedida." % get_instance_id())
	await _say(["Guardá esas respuestas cerca del corazón.", "Tu camino empieza ahora."])
	print("[NewGameCeremony:%s] Despedida terminada." % get_instance_id())
	_sequence_completed = true
	_enter_world()


func _settle_facing_camera() -> void:
	if _model == null:
		return
	var final_position := _model.position
	_model.queue_free()
	_model = _instantiate_model(_data.scene_idle if _data.scene_idle != null else _data.scene_walk)
	if _model == null:
		return
	_model.position = final_position
	_model.rotation.y = -PI * 0.5
	add_child(_model)
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Con la orientación propia de este modelo, 0 es mirar a la cámara.
	turn.tween_property(_model, "rotation:y", 0.0, 0.55)
	await turn.finished


func _say(lines: Array[String]) -> void:
	print("[NewGameCeremony:%s] Dialogue.start: %s" % [get_instance_id(), " | ".join(lines)])
	DialogueLines.say_many(_data, lines)
	await Dialogue.dialogue_finished
	print("[NewGameCeremony:%s] Dialogue.finished." % get_instance_id())


func _ask(question: String, options: Array[String]) -> int:
	print("[NewGameCeremony:%s] Pregunta: %s" % [get_instance_id(), question])
	await _say([question])
	print("[NewGameCeremony:%s] Abriendo opciones: %s" % [get_instance_id(), " | ".join(options)])
	var choice: int = await Dialogue.ask(options)
	print("[NewGameCeremony:%s] Opción recibida: %s" % [get_instance_id(), choice])
	if choice >= 0 and choice < options.size():
		await _say(["Comprendo. Elegís: %s" % options[choice]])
	return choice


func _apply_starting_youn(path: String) -> void:
	var save := GameState.player_save
	if save == null:
		return
	GameState.save_service.setup_starting_youn(save, GameState.get_total_hours(), path)
	print("[NewGameCeremony:%s] Youn inicial elegido: %s." % [get_instance_id(), path])


func _starting_youn_name() -> String:
	var save := GameState.player_save
	if save == null:
		return "Compañero"
	var data := load(save.current_youn_path) as YounData
	return data.youn_name if data != null else "Compañero"


func _save_ceremony_names() -> void:
	var save := GameState.player_save
	if save == null:
		return
	save.player_name = _player_name
	save.companion_name = _companion_name


func _ask_name(prompt: String, placeholder: String) -> String:
	await _say([prompt])
	print("[NewGameCeremony:%s] Abriendo teclado virtual para: %s" % [get_instance_id(), prompt])
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.size = Vector2(720, 530)
	panel.position -= panel.size * 0.5
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var label := Label.new()
	label.text = prompt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	column.add_child(label)
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.max_length = 24
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_size_override("font_size", 22)
	column.add_child(input)
	var help := Label.new()
	help.text = "Cruceta: mover · Aceptar: elegir · Cancelar: borrar"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 16)
	column.add_child(help)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)

	# El teclado es deliberadamente propio: así funciona con mando aun cuando la
	# plataforma no expone el teclado nativo del sistema a Godot.
	var keys: Array[String] = [
		"A", "B", "C", "D", "E", "F", "G",
		"H", "I", "J", "K", "L", "M", "N",
		"Ñ", "O", "P", "Q", "R", "S", "T",
		"U", "V", "W", "X", "Y", "Z",
		"MAYÚS", "ESPACIO", "BORRAR", "LISTO",
	]
	var key_buttons: Array[Button] = []
	for key in keys:
		var key_button := Button.new()
		key_button.text = key
		key_button.custom_minimum_size = Vector2(82, 48)
		key_button.add_theme_font_size_override("font_size", 18 if key.length() == 1 else 14)
		grid.add_child(key_button)
		key_buttons.append(key_button)

	# Las lambdas de GDScript capturan variables locales por valor. Este estado
	# compartido permite que los botones y el bucle de navegación vean el mismo
	# valor de selección, mayúsculas y confirmación.
	var keyboard_state := {
		"selected": 0,
		"uppercase": true,
		"submitted": false,
	}
	var input_unlocked := false
	var refresh_key_labels := func() -> void:
		for key_index in keys.size():
			var key := keys[key_index]
			if key.length() == 1:
				key_buttons[key_index].text = key.to_upper() if keyboard_state["uppercase"] else key.to_lower()
			elif key == "MAYÚS":
				key_buttons[key_index].text = "MINÚS" if keyboard_state["uppercase"] else "MAYÚS"
			else:
				key_buttons[key_index].text = key
	input.grab_focus()
	var try_submit := func() -> void:
		if input.text.strip_edges().is_empty():
			help.text = "Elegí un nombre antes de continuar."
			return
		keyboard_state["submitted"] = true
	var select_key := func(index: int) -> void:
		keyboard_state["selected"] = posmod(index, key_buttons.size())
		for button_index in key_buttons.size():
			key_buttons[button_index].modulate = Color(1.0, 0.88, 0.42) if button_index == keyboard_state["selected"] else Color.WHITE
	select_key.call(keyboard_state["selected"])
	var activate_key := func(index: int) -> void:
		match keys[index]:
			"MAYÚS":
				keyboard_state["uppercase"] = not keyboard_state["uppercase"]
				refresh_key_labels.call()
			"ESPACIO":
				if input.text.length() < input.max_length:
					input.text += " "
			"BORRAR":
				if not input.text.is_empty():
					input.text = input.text.substr(0, input.text.length() - 1)
			"LISTO":
				try_submit.call()
			_:
				if input.text.length() < input.max_length:
					input.text += (keys[index].to_upper() if keyboard_state["uppercase"] else keys[index].to_lower())
		input.caret_column = input.text.length()
		input.grab_focus()
	for button_index in key_buttons.size():
		key_buttons[button_index].pressed.connect(activate_key.bind(button_index))
	while not keyboard_state["submitted"]:
		await get_tree().process_frame
		# El mismo Enter/A que termina el diálogo anterior puede seguir pulsado
		# durante el primer frame del teclado. Esperamos su liberación para que
		# nunca confirme un nombre accidentalmente.
		if not input_unlocked:
			if not Input.is_action_pressed("ui_accept") and not Input.is_key_pressed(KEY_ENTER) and not Input.is_key_pressed(KEY_KP_ENTER):
				input_unlocked = true
			continue
		# Enter pertenece al teclado físico: confirma el texto completo. ui_accept
		# queda reservado al botón de aceptar del mando dentro de la grilla.
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
			try_submit.call()
		elif Input.is_physical_key_pressed(KEY_SPACE):
			# El LineEdit enfocado recibe el espacio del teclado físico.
			pass
		elif Input.is_action_just_pressed("ui_left"):
			select_key.call(keyboard_state["selected"] - 1)
		elif Input.is_action_just_pressed("ui_right"):
			select_key.call(keyboard_state["selected"] + 1)
		elif Input.is_action_just_pressed("ui_up"):
			select_key.call(keyboard_state["selected"] - 7)
		elif Input.is_action_just_pressed("ui_down"):
			select_key.call(keyboard_state["selected"] + 7)
		elif Input.is_action_just_pressed("ui_cancel"):
			activate_key.call(keys.find("BORRAR"))
		elif Input.is_action_just_pressed("ui_accept"):
			activate_key.call(keyboard_state["selected"])
	var result := input.text.strip_edges()
	layer.queue_free()
	print("[NewGameCeremony:%s] Nombre confirmado: %s" % [get_instance_id(), result if not result.is_empty() else placeholder])
	return result if not result.is_empty() else placeholder


func _enter_world() -> void:
	if not _sequence_completed:
		push_warning("[NewGameCeremony:%s] Se ignoró una transición prematura al mundo." % get_instance_id())
		return
	if _entering_world:
		return
	_entering_world = true
	print("[NewGameCeremony:%s] _enter_world: preparando entrada al mundo." % get_instance_id())
	GameState.new_game_ceremony_completed = true
	call_deferred("_change_to_world")


func _change_to_world() -> void:
	print("[NewGameCeremony:%s] change_scene_to_file(WorldLoading)." % get_instance_id())
	get_tree().paused = false
	var result := get_tree().change_scene_to_file(WORLD_LOADING)
	if result != OK:
		push_error("NewGameCeremony: no se pudo cargar WorldLoading (%s)." % result)
