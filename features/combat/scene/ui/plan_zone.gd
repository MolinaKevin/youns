extends VBoxContainer

## Zona donde se ubican las 2 cartas elegidas en la planificación.
## Espacio 0 (izquierda): define la iniciativa. Espacio 1 (derecha): segunda carta.
## Qué mitad se usa de cada una se elige después, en la fase de acción.
## Acepta drops con payload {"source": "hand" | "slot", "index": int}.

signal slot_clicked(slot: int)
signal slot_dropped(slot: int, data: Dictionary)
signal confirm_pressed

const CARD_SCENE := preload("res://features/cards/presentation/card_view.tscn")
const CARD_SIZE := Vector2(195, 293)
const CARD_SCALE := 0.6

var _initiative_label: Label
var _slot_titles: Array[Label] = []
var _slot_holders: Array[Panel] = []
var _confirm_button: Button

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 6)

	_initiative_label = Label.new()
	_initiative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initiative_label.add_theme_font_size_override("font_size", 18)
	add_child(_initiative_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for k in 2:
		var column := VBoxContainer.new()
		row.add_child(column)
		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 12)
		column.add_child(title)
		_slot_titles.append(title)
		var holder := Panel.new()
		holder.custom_minimum_size = CARD_SIZE * CARD_SCALE
		holder.set_drag_forwarding(Callable(), _can_drop_on_slot, _drop_on_slot.bind(k))
		column.add_child(holder)
		_slot_holders.append(holder)

	_confirm_button = Button.new()
	_confirm_button.pressed.connect(func(): confirm_pressed.emit())
	add_child(_confirm_button)

## cards: [CardData o null, CardData o null]; initiative: la de la izquierda o -1.
## enemy_initiative: texto, porque con mazo de monstruo no se conoce hasta confirmar.
func set_state(cards: Array, initiative: int, enemy_initiative: String) -> void:
	_slot_titles[0].text = LocalizationState.t("combat.slot_lead")
	_slot_titles[1].text = LocalizationState.t("combat.slot_second")
	_confirm_button.text = LocalizationState.t("combat.confirm_plan")
	_confirm_button.disabled = cards[0] == null or cards[1] == null
	_initiative_label.text = LocalizationState.t("combat.current_initiative", [
		str(initiative) if initiative >= 0 else "—", enemy_initiative
	])
	for k in 2:
		_fill_slot(k, cards[k])

func _fill_slot(k: int, card: CardData) -> void:
	var holder := _slot_holders[k]
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if card == null:
		var hint := Label.new()
		hint.text = LocalizationState.t("combat.slot_empty")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.set_anchors_preset(Control.PRESET_FULL_RECT)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(hint)
		return
	var view = CARD_SCENE.instantiate()
	view.hover_enabled = false
	view.scale = Vector2(CARD_SCALE, CARD_SCALE)
	view.drag_payload = {"source": "slot", "index": k}
	view.can_drop_callback = func(data): return _accepts(data)
	view.drop_callback = func(data): slot_dropped.emit(k, data)
	view.card_pressed.connect(func(_c): slot_clicked.emit(k))
	holder.add_child(view)
	view.set_card(card)

func _accepts(data: Variant) -> bool:
	return data is Dictionary and data.get("source", "") in ["hand", "slot"]

func _can_drop_on_slot(_at: Vector2, data: Variant) -> bool:
	return _accepts(data)

func _drop_on_slot(_at: Vector2, data: Variant, k: int) -> void:
	slot_dropped.emit(k, data)
