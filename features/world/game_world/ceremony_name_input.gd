extends RefCounted

## Teclado de nombres reutilizable para secuencias que no pueden depender del
## teclado nativo. El dueño conserva el control del flujo de la ceremonia.

var _owner: Node
var _flow


func _init(owner: Node, flow) -> void:
	_owner = owner
	_flow = flow


func ask(prompt: String, placeholder: String) -> String:
	var layer := CanvasLayer.new()
	layer.layer = 90
	_owner.add_child(layer)
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
	help.text = LocalizationState.t("ceremony.keyboard_hint")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 16)
	column.add_child(help)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)

	var keys: Array[String] = [
		"A", "B", "C", "D", "E", "F", "G",
		"H", "I", "J", "K", "L", "M", "N",
		"Ñ", "O", "P", "Q", "R", "S", "T",
		"U", "V", "W", "X", "Y", "Z",
		LocalizationState.t("ceremony.key_upper"), LocalizationState.t("ceremony.key_space"), LocalizationState.t("ceremony.key_delete"), LocalizationState.t("ceremony.key_done"),
	]
	var key_buttons: Array[Button] = []
	for key in keys:
		var key_button := Button.new()
		key_button.text = key
		key_button.custom_minimum_size = Vector2(82, 48)
		key_button.add_theme_font_size_override("font_size", 18 if key.length() == 1 else 14)
		grid.add_child(key_button)
		key_buttons.append(key_button)

	var keyboard_state := {"selected": 0, "uppercase": true, "submitted": false}
	var input_unlocked := false
	var refresh_key_labels := func() -> void:
		for key_index in keys.size():
			var key := keys[key_index]
			if key.length() == 1:
				key_buttons[key_index].text = key.to_upper() if keyboard_state["uppercase"] else key.to_lower()
			elif key == LocalizationState.t("ceremony.key_upper"):
				key_buttons[key_index].text = LocalizationState.t("ceremony.key_lower") if keyboard_state["uppercase"] else LocalizationState.t("ceremony.key_upper")
			else:
				key_buttons[key_index].text = key
	input.grab_focus()
	var try_submit := func() -> void:
		if input.text.strip_edges().is_empty():
			help.text = LocalizationState.t("ceremony.name_required")
			return
		keyboard_state["submitted"] = true
	var select_key := func(index: int) -> void:
		keyboard_state["selected"] = posmod(index, key_buttons.size())
		for button_index in key_buttons.size():
			key_buttons[button_index].modulate = Color(1.0, 0.88, 0.42) if button_index == keyboard_state["selected"] else Color.WHITE
	select_key.call(keyboard_state["selected"])
	var activate_key := func(index: int) -> void:
		var key := keys[index]
		if key == LocalizationState.t("ceremony.key_upper"):
			keyboard_state["uppercase"] = not keyboard_state["uppercase"]
			refresh_key_labels.call()
		elif key == LocalizationState.t("ceremony.key_space"):
			if input.text.length() < input.max_length:
				input.text += " "
		elif key == LocalizationState.t("ceremony.key_delete"):
			if not input.text.is_empty():
				input.text = input.text.substr(0, input.text.length() - 1)
		elif key == LocalizationState.t("ceremony.key_done"):
			try_submit.call()
		elif input.text.length() < input.max_length:
			input.text += (key.to_upper() if keyboard_state["uppercase"] else key.to_lower())
		input.caret_column = input.text.length()
		input.grab_focus()
	for button_index in key_buttons.size():
		key_buttons[button_index].pressed.connect(activate_key.bind(button_index))
	while not keyboard_state["submitted"]:
		await _owner.get_tree().process_frame
		if _flow == null or not _flow.is_active():
			if is_instance_valid(layer):
				layer.queue_free()
			return ""
		# Esperar la liberación evita que el Enter del diálogo anterior confirme
		# accidentalmente el campo recién abierto.
		if not input_unlocked:
			if not Input.is_action_pressed("ui_accept") and not Input.is_key_pressed(KEY_ENTER) and not Input.is_key_pressed(KEY_KP_ENTER):
				input_unlocked = true
			continue
		if Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER):
			try_submit.call()
		elif Input.is_physical_key_pressed(KEY_SPACE):
			pass # El LineEdit enfocado recibe el espacio físico.
		elif Input.is_action_just_pressed("ui_left"):
			select_key.call(keyboard_state["selected"] - 1)
		elif Input.is_action_just_pressed("ui_right"):
			select_key.call(keyboard_state["selected"] + 1)
		elif Input.is_action_just_pressed("ui_up"):
			select_key.call(keyboard_state["selected"] - 7)
		elif Input.is_action_just_pressed("ui_down"):
			select_key.call(keyboard_state["selected"] + 7)
		elif Input.is_action_just_pressed("ui_cancel"):
			activate_key.call(keys.find(LocalizationState.t("ceremony.key_delete")))
		elif Input.is_action_just_pressed("ui_accept"):
			activate_key.call(keyboard_state["selected"])
	var result := input.text.strip_edges()
	layer.queue_free()
	return result if not result.is_empty() else placeholder
