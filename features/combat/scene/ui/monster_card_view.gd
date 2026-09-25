extends PanelContainer

## Carta de habilidad del monstruo para esta ronda: iniciativa y nombre arriba,
## y la lista de acciones que ejecuta en orden. Cada acción muestra el
## modificador de la carta y, entre paréntesis, el valor final.

const BG        := Color(0.22, 0.03, 0.05, 0.95)
const BORDER    := Color(0.85, 0.2, 0.2)
const TEXT      := Color(0.95, 0.9, 0.88)
const NOTE      := Color(0.85, 0.75, 0.72)
const ACTIVE    := Color(1.0, 0.85, 0.35)

var _initiative_label: Label
var _name_label: Label
var _actions_box: VBoxContainer
## Una lista de labels por acción (para resaltar la acción en curso).
var _rows: Array = []
## Lugar de descanso (arriba a la izquierda, según la escena).
var _home := Vector2.ZERO
var _tween: Tween

func _ready() -> void:
	_home = position
	custom_minimum_size = Vector2(230, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	_initiative_label = Label.new()
	_initiative_label.add_theme_font_size_override("font_size", 26)
	_initiative_label.add_theme_color_override("font_color", TEXT)
	header.add_child(_initiative_label)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", TEXT)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_name_label)

	var divider := ColorRect.new()
	divider.color = BORDER
	divider.custom_minimum_size = Vector2(0, 2)
	column.add_child(divider)

	_actions_box = VBoxContainer.new()
	_actions_box.add_theme_constant_override("separation", 4)
	column.add_child(_actions_box)
	visible = false

func show_card(card: MonsterCard, deck: MonsterDeck) -> void:
	_initiative_label.text = str(card.initiative)
	_name_label.text = card.card_name
	for child in _actions_box.get_children():
		_actions_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	for action in card.actions:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		var labels: Array[Label] = []
		for part in _action_parts(action, deck):
			var group := HBoxContainer.new()
			group.add_theme_constant_override("separation", 4)
			var tex := TextureRect.new()
			tex.texture = CardText.icon(part[0])
			tex.custom_minimum_size = Vector2(24, 24)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			group.add_child(tex)
			var label := Label.new()
			label.text = part[1]
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", TEXT)
			group.add_child(label)
			labels.append(label)
			row.add_child(group)
		_actions_box.add_child(row)
		_rows.append(labels)
		if action.note != "":
			var note := Label.new()
			note.text = action.note
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.add_theme_font_size_override("font_size", 11)
			note.add_theme_color_override("font_color", NOTE)
			_actions_box.add_child(note)
	visible = true

## Muestra la carta agrandada con su centro en `center` (al revelar la ronda).
## Hay que llamarla después de show_card y de que el panel tenga su tamaño.
func present_at(center: Vector2, zoom: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	reset_size()
	pivot_offset = size * 0.5
	scale = Vector2(zoom, zoom)
	position = center - size * 0.5

## Vuelve volando a su lugar de arriba a la izquierda, a tamaño normal.
func return_home(duration := 0.35) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", _home, duration)
	_tween.tween_property(self, "scale", Vector2.ONE, duration)
	await _tween.finished

## Deja la carta en su lugar sin animación.
func snap_home() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	position = _home
	scale = Vector2.ONE

## Resalta la acción que se está ejecutando; -1 quita el resaltado.
func highlight(index: int) -> void:
	for i in _rows.size():
		for label: Label in _rows[i]:
			label.add_theme_color_override("font_color", ACTIVE if i == index else TEXT)

## [[ícono, texto]] de una acción: modificador de la carta y, entre paréntesis,
## el valor final (distancias en casillas).
static func _action_parts(action: MonsterCardAction, deck: MonsterDeck) -> Array:
	match action.type:
		"move", "retreat":
			return [[action.type, "%s (%d)" % [_signed(action.value), deck.move_for(action)]]]
		"attack":
			var ranged := deck.base_range > 0
			var parts := [["bow" if ranged else "sword", "%s (%d)" % [_signed(action.value), deck.attack_for(action)]]]
			if ranged:
				parts.append(["target", "%s (%d)" % [_signed(action.range_modifier), deck.reach_for(action)]])
			return parts
		"block":
			return [["shield", str(action.value)]]
		"heal":
			return [["heal", str(action.value)]]
	return []

static func _signed(v: int) -> String:
	return "+%d" % v if v >= 0 else str(v)
