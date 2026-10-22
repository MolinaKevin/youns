class_name CombatEnemyRevealPresentation
extends RefCounted

var _ui_root: Node
var _card_view
var _start_button: Button
var _backs: Array[Control] = []

func setup(ui_root: Node, card_view) -> void:
	_ui_root = ui_root
	_card_view = card_view
	_start_button = Button.new()
	_start_button.custom_minimum_size = Vector2(240, 52)
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.visible = false
	_ui_root.add_child(_start_button)

func present_and_wait(monster_card: MonsterCard, monster_deck, options: Array, zoom: float, back_scale: float, spacing_ratio: float) -> void:
	var screen := _ui_root.get_viewport().get_visible_rect().size
	var button_y := screen.y * 0.5
	if monster_card != null:
		_card_view.show_card(monster_card, monster_deck)
		await _ui_root.get_tree().process_frame
		var chosen_size: Vector2 = _card_view.size * zoom
		var count := maxi(1, options.size())
		var chosen_slot := maxi(0, options.find(monster_card))
		var row_y := screen.y * 0.36
		var spacing := chosen_size.x * spacing_ratio
		var centers: Array[Vector2] = []
		for i in count: centers.append(Vector2(screen.x * 0.5 + (i - (count - 1) * 0.5) * spacing, row_y))
		_card_view.present_at(centers[chosen_slot], zoom)
		button_y = row_y + chosen_size.y * 0.5 + 24.0
		_show_backs(centers, chosen_slot, chosen_size * back_scale)
	_start_button.text = LocalizationState.t("combat.start_round")
	_start_button.reset_size()
	_start_button.position = Vector2(screen.x * 0.5 - _start_button.size.x * 0.5, button_y)
	_start_button.visible = true
	await _start_button.pressed
	_start_button.visible = false
	_hide_backs()
	if monster_card != null: await _card_view.return_home()

func hide() -> void:
	_start_button.visible = false
	_clear_backs()

func apply_localization() -> void:
	_start_button.text = LocalizationState.t("combat.start_round")
	_start_button.reset_size()
	if _start_button.visible:
		var screen := _ui_root.get_viewport().get_visible_rect().size
		_start_button.position.x = screen.x * 0.5 - _start_button.size.x * 0.5

func _show_backs(centers: Array[Vector2], chosen_slot: int, back_size: Vector2) -> void:
	_clear_backs()
	for i in centers.size():
		if i == chosen_slot: continue
		var back := _make_back(back_size)
		_ui_root.add_child(back); _ui_root.move_child(back, _card_view.get_index())
		back.position = centers[i] - back_size * 0.5; back.pivot_offset = back_size * 0.5
		back.rotation_degrees = (i - (centers.size() - 1) * 0.5) * 7.0
		_backs.append(back)

func _hide_backs() -> void:
	for back in _backs:
		var tween := back.create_tween(); tween.tween_property(back, "modulate:a", 0.0, 0.25); tween.tween_callback(back.queue_free)
	_backs.clear()

func _clear_backs() -> void:
	for back in _backs: back.queue_free()
	_backs.clear()

func _make_back(size: Vector2) -> PanelContainer:
	var back := PanelContainer.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE; back.custom_minimum_size = size; back.size = size
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.14, 0.02, 0.04, 0.97); style.border_color = Color(0.85, 0.2, 0.2)
	style.set_border_width_all(3); style.set_corner_radius_all(8); back.add_theme_stylebox_override("panel", style)
	var mark := Label.new(); mark.text = "?"; mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", int(size.y * 0.35)); mark.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2, 0.8)); back.add_child(mark)
	return back
