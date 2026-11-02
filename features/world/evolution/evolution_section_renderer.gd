class_name EvolutionSectionRenderer
extends RefCounted

const GAIN := Color(0.5, 1.0, 0.55)
const LOSS := Color(1.0, 0.45, 0.4)

static func build_stats(content: VBoxContainer, changes: Dictionary) -> void:
	if changes.is_empty():
		content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for key in YounStats.KEYS:
		if not changes.has(key):
			continue
		var delta: int = changes[key]
		var name_label := Label.new()
		name_label.text = LocalizationState.t("youn_stat." + key)
		name_label.add_theme_font_size_override("font_size", 20)
		grid.add_child(name_label)
		var value := Label.new()
		value.text = ("+%d" if delta > 0 else "%d") % delta
		value.add_theme_font_size_override("font_size", 20)
		value.add_theme_color_override("font_color", GAIN if delta > 0 else LOSS)
		grid.add_child(value)

static func build_card(content: VBoxContainer, card: CardData) -> void:
	if card == null:
		content.add_child(_note(LocalizationState.t("evolution.no_changes")))
		return
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	CardGridEntry.build(center, card)

static func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	return label
