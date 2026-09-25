extends Control

signal card_selected(card_data: CardData)
signal card_index_selected(index: int)
signal half_selected(index: int, is_top: bool)

@onready var section_label = $VBox/SectionLabel
@onready var fan_container = $VBox/FanContainer

var card_scene = preload("res://features/cards/presentation/card_view.tscn")

const CARD_W      := 195.0
const CARD_H      := 293.0
const X_SPACING   := 120.0
const FAN_RADIUS  := 800.0
const HOVER_RISE  := 130.0
const HOVER_SECS  := 0.12

## Si no está vacío, las cartas se pueden arrastrar con payload {"source": drag_source, "index": i}.
var drag_source := ""
## Si es true, cada mitad de la carta se toca por separado (emite half_selected).
var halves_mode := false

var _fan_data:    Dictionary = {}
var _hover_tweens: Dictionary = {}
## Control opcional que va entre las dos cartas en modo mitades (p. ej. comodines).
var _middle: Control = null

func _ready() -> void:
	fan_container.resized.connect(_arrange_fan)

func set_middle_control(control: Control) -> void:
	_middle = control
	if control.get_parent() != null:
		control.reparent(self)
	else:
		add_child(control)
	_arrange_fan.call_deferred()

func set_title(title: String) -> void:
	section_label.text = title

func set_cards(cards: Array) -> void:
	_fan_data.clear()
	_hover_tweens.clear()
	for child in fan_container.get_children():
		fan_container.remove_child(child)
		child.queue_free()

	for i in cards.size():
		var card = cards[i]
		var wrapper := Control.new()
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fan_container.add_child(wrapper)

		var card_view = card_scene.instantiate()
		wrapper.add_child(card_view)
		card_view.setup(card)
		card_view.halves_selectable = halves_mode
		card_view.half_pressed.connect(func(_c, is_top): half_selected.emit(i, is_top))
		if drag_source != "":
			card_view.drag_payload = {"source": drag_source, "index": i}
		card_view.card_pressed.connect(_on_card_pressed.bind(i))
		card_view.hover_entered.connect(_on_card_hover_enter.bind(wrapper))
		card_view.hover_exited.connect(_on_card_hover_exit.bind(wrapper))

	_arrange_fan.call_deferred()

func _arrange_fan() -> void:
	var wrappers := fan_container.get_children()
	var n := wrappers.size()
	if n == 0:
		return

	var cx: float = fan_container.size.x * 0.5
	if cx <= 0.0:
		return

	var middle_w := 0.0
	var show_middle := halves_mode and n == 2 and _middle != null and _middle.visible
	if show_middle:
		middle_w = _middle.get_combined_minimum_size().x + 16.0
	# En modo mitades las cartas no se superponen: hay que poder tocar cada mitad entera.
	var spacing := CARD_W + 16.0 + middle_w if halves_mode else X_SPACING
	var total_span := spacing * float(max(n - 1, 0))
	var pivot_base_y: float = fan_container.size.y

	for i in n:
		var wrapper = wrappers[i]
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		var x_offset := t * total_span
		var angle := 0.0
		var y_drop := 0.0
		# En modo mitades las cartas van derechas, sin abanico.
		if not halves_mode:
			angle = asin(clampf(x_offset / FAN_RADIUS, -1.0, 1.0))
			y_drop = FAN_RADIUS - sqrt(maxf(0.0, FAN_RADIUS * FAN_RADIUS - x_offset * x_offset))
		var z := n / 2 - absi(i - n / 2)

		wrapper.pivot_offset = Vector2(CARD_W * 0.5, CARD_H)
		wrapper.position = Vector2(cx + x_offset - CARD_W * 0.5, pivot_base_y + y_drop - CARD_H)
		wrapper.rotation = angle
		wrapper.z_index = z

		_fan_data[wrapper] = {
			"position": wrapper.position,
			"rotation": angle,
			"z_index": z,
		}

	if show_middle:
		var middle_size := _middle.get_combined_minimum_size()
		_middle.size = middle_size
		_middle.position = fan_container.position + Vector2(
			cx - middle_size.x * 0.5,
			pivot_base_y - CARD_H * 0.5 - middle_size.y * 0.5
		)

func _on_card_hover_enter(wrapper: Control) -> void:
	# En modo mitades la carta no sube: si subiera, el mouse se saldría de la mitad ▼.
	if wrapper not in _fan_data or halves_mode:
		return
	var base: Dictionary = _fan_data[wrapper]
	_kill_tween(wrapper)
	wrapper.z_index = 200
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrapper, "position:y", (base["position"] as Vector2).y - HOVER_RISE, HOVER_SECS)
	tw.tween_property(wrapper, "rotation", 0.0, HOVER_SECS)
	_hover_tweens[wrapper] = tw

func _on_card_hover_exit(wrapper: Control) -> void:
	if wrapper not in _fan_data or halves_mode:
		return
	var base: Dictionary = _fan_data[wrapper]
	_kill_tween(wrapper)
	wrapper.z_index = base["z_index"]
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrapper, "position:y", (base["position"] as Vector2).y, HOVER_SECS)
	tw.tween_property(wrapper, "rotation", base["rotation"] as float, HOVER_SECS)
	_hover_tweens[wrapper] = tw

func _kill_tween(wrapper: Control) -> void:
	if wrapper in _hover_tweens:
		var tw = _hover_tweens[wrapper]
		if tw and tw.is_valid():
			tw.kill()
		_hover_tweens.erase(wrapper)

func set_card_visible_at(index: int, is_visible: bool) -> void:
	var wrappers := fan_container.get_children()
	if index >= 0 and index < wrappers.size():
		wrappers[index].visible = is_visible

func set_half_enabled(index: int, is_top: bool, enabled: bool) -> void:
	var wrappers := fan_container.get_children()
	if index < 0 or index >= wrappers.size():
		return
	for child in wrappers[index].get_children():
		if child.has_method("set_half_enabled"):
			child.set_half_enabled(is_top, enabled)

func show_all_cards() -> void:
	for w in fan_container.get_children():
		w.visible = true

func disable_cards() -> void:
	for wrapper in fan_container.get_children():
		for child in wrapper.get_children():
			if child.has_method("set_disabled"):
				child.set_disabled(true)

func _on_card_pressed(card_data: CardData, index: int) -> void:
	card_selected.emit(card_data)
	card_index_selected.emit(index)
