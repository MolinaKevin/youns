extends Control

## Carta partida en dos: nombre, mitad superior (▲), iniciativa al medio y
## mitad inferior (▼). Por defecto se toca la carta entera; con
## halves_selectable cada mitad se toca por separado (fase de acción).

signal card_pressed(card_data: CardData)
signal half_pressed(card_data: CardData, is_top: bool)
signal hover_entered
signal hover_exited

@onready var frame = $Frame
@onready var name_label = $NameLabel
@onready var top_half: Button = $TopHalf
@onready var bottom_half: Button = $BottomHalf
@onready var initiative_badge = $InitiativeBadge
@onready var initiative_label = $InitiativeBadge/InitiativeLabel
@onready var card_button: Button = $CardButton

var card_data: CardData
var pending_setup_card: CardData
var hover_enabled := true
## Si no es null, la carta se puede arrastrar y este valor es el dato del drag.
var drag_payload = null
## Opcionales: (data) -> bool y (data) -> void para aceptar drops sobre la carta.
var can_drop_callback: Callable
var drop_callback: Callable
## true: cada mitad es un botón propio y la carta entera no se puede tocar.
var halves_selectable := false:
	set(value):
		halves_selectable = value
		if is_node_ready():
			_apply_input_mode()

var _hover_tween: Tween
var _empty_style := StyleBoxEmpty.new()

const FRAME_BG     := Color(0.07, 0.16, 0.24)
const FRAME_BORDER := Color(0.35, 0.85, 1.0)
const HALF_BORDER  := Color(1.0, 0.85, 0.35)

func _ready() -> void:
	_apply_styles()
	card_button.pressed.connect(_on_card_button_pressed)
	card_button.mouse_entered.connect(_on_hover_enter)
	card_button.mouse_exited.connect(_on_hover_exit)
	# El botón tapa toda la carta, así que recibe el mouse: le reenviamos el drag & drop.
	card_button.set_drag_forwarding(_get_drag_data_fw, _can_drop_data_fw, _drop_data_fw)
	for half: Button in [top_half, bottom_half]:
		var is_top := half == top_half
		half.pressed.connect(func(): half_pressed.emit(card_data, is_top))
		half.mouse_entered.connect(_on_hover_enter)
		half.mouse_exited.connect(_on_hover_exit)
	_apply_input_mode()

	if pending_setup_card != null:
		_apply_card_data(pending_setup_card)
		pending_setup_card = null

func _apply_styles() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = FRAME_BG
	bg.border_color = FRAME_BORDER
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", bg)

	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.03, 0.08, 0.12)
	badge.border_color = FRAME_BORDER
	badge.set_border_width_all(2)
	badge.set_corner_radius_all(8)
	initiative_badge.add_theme_stylebox_override("panel", badge)

	for half: Button in [top_half, bottom_half]:
		half.add_theme_stylebox_override("focus", _empty_style)

func _apply_input_mode() -> void:
	card_button.visible = not halves_selectable
	for half: Button in [top_half, bottom_half]:
		half.mouse_filter = Control.MOUSE_FILTER_STOP if halves_selectable else Control.MOUSE_FILTER_IGNORE
	_refresh_half_styles()

## Fondo de cada mitad con su color. En modo mitades se suma el borde de botón
## y el resaltado dorado al pasar el mouse.
func _refresh_half_styles() -> void:
	for half: Button in [top_half, bottom_half]:
		var action: CardAction = null
		if card_data != null:
			action = card_data.top if half == top_half else card_data.bottom
		if action == null:
			for state in ["normal", "hover", "pressed", "disabled"]:
				half.add_theme_stylebox_override(state, _empty_style)
			continue
		var normal := _half_style(action.color, Color(FRAME_BORDER, 0.6) if halves_selectable else Color.TRANSPARENT)
		var hover := _half_style(action.color.lightened(0.15), HALF_BORDER)
		half.add_theme_stylebox_override("normal", normal)
		half.add_theme_stylebox_override("disabled", _half_style(action.color, Color.TRANSPARENT))
		half.add_theme_stylebox_override("hover", hover if halves_selectable else normal)
		half.add_theme_stylebox_override("pressed", hover if halves_selectable else normal)

static func _half_style(bg: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2 if border.a > 0.0 else 0)
	st.set_corner_radius_all(6)
	return st

func _on_hover_enter() -> void:
	if hover_enabled:
		hover_entered.emit()
		_animate_to(-12.0)

func _on_hover_exit() -> void:
	if hover_enabled:
		hover_exited.emit()
		_animate_to(0.0)

func _animate_to(target_y: float) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "position:y", target_y, 0.12)

func setup(card: CardData) -> void:
	set_card(card)

func set_card(card: CardData) -> void:
	card_data = card

	if not is_node_ready():
		pending_setup_card = card
		return

	_apply_card_data(card)

func _apply_card_data(card: CardData) -> void:
	name_label.text = LocalizationState.card_name(card.id, card.name)
	initiative_label.text = str(card.initiative)
	_fill_half(top_half, card.top, "▲")
	_fill_half(bottom_half, card.bottom, "▼")
	_refresh_half_styles()

## Una fila por línea de acción: íconos con su número (ver CardText.line_parts).
func _fill_half(half: Button, action: CardAction, marker: String) -> void:
	var box: VBoxContainer = half.get_node("VBox")
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if action == null:
		return
	# Se muestra el valor final para el Youn del jugador (ver StatScaling).
	var stats := CardScaling.player_stats()
	var lines := action.lines
	for i in lines.size():
		var line: CardActionLine = lines[i]
		if line == null:
			continue
		var row := _line_row(line.resolved(stats), marker if i == 0 else "")
		if not line.enabled:
			row.modulate.a = 0.35
		box.add_child(row)

const ICON_SIZE := 22.0
const PART_GAP := 12

static func _line_row(line: CardActionLine, marker: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", PART_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if marker != "":
		row.add_child(_small_label(marker, 12))
	for part in CardText.line_parts(line):
		var group := HBoxContainer.new()
		group.add_theme_constant_override("separation", 3)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if part["icon"] != null:
			var tex := TextureRect.new()
			tex.texture = part["icon"]
			tex.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.modulate = part["color"]
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_child(tex)
		if part["value"] != "":
			group.add_child(_small_label(part["value"], 16))
		row.add_child(group)
	return row

static func _small_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Habilita o apaga una mitad (se ve atenuada y no se puede tocar).
func set_half_enabled(is_top: bool, enabled: bool) -> void:
	var half: Button = top_half if is_top else bottom_half
	half.disabled = not enabled
	half.modulate.a = 1.0 if enabled else 0.3

func _get_drag_data_fw(_at: Vector2) -> Variant:
	if drag_payload == null or card_button.disabled:
		return null
	var preview := Control.new()
	var ghost = load("res://features/cards/presentation/card_view.tscn").instantiate()
	ghost.hover_enabled = false
	ghost.set_card(card_data)
	ghost.scale = Vector2(0.6, 0.6)
	ghost.position = -custom_minimum_size * 0.3
	ghost.modulate.a = 0.85
	preview.add_child(ghost)
	set_drag_preview(preview)
	return drag_payload

func _can_drop_data_fw(_at: Vector2, data: Variant) -> bool:
	return can_drop_callback.is_valid() and can_drop_callback.call(data)

func _drop_data_fw(_at: Vector2, data: Variant) -> void:
	if drop_callback.is_valid():
		drop_callback.call(data)

func set_disabled(value: bool) -> void:
	card_button.disabled = value
	top_half.disabled = value
	bottom_half.disabled = value

func _on_card_button_pressed() -> void:
	card_pressed.emit(card_data)
