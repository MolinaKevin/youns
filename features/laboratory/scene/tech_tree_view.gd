extends Control

const LabRecipeAction := preload("res://data/lab_recipe_action.gd")
const TechTreeLayout := preload("res://features/laboratory/scene/tech_tree_layout.gd")

var _layout: TechTreeLayout

func _ready() -> void:
	LaboratoryState.recipes_loaded.connect(_build)
	LaboratoryState.recipe_unlocked.connect(func(_r): _build())
	if LaboratoryState.all_recipes.size() > 0:
		_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var recipes := LaboratoryState.all_recipes.filter(
		func(r): return LaboratoryState.is_recipe_unlocked(r.id) or LaboratoryState.is_recipe_completed(r.id)
	)
	_layout = TechTreeLayout.new(recipes)
	if recipes.is_empty():
		queue_redraw()
		return

	custom_minimum_size = _layout.canvas_size
	for r in recipes:
		_create_node(r)

	queue_redraw()

func _create_node(recipe: Resource) -> void:
	var pos: Vector2 = _layout.positions.get(recipe.id, Vector2.ZERO)

	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(TechTreeLayout.NODE_W, TechTreeLayout.NODE_H)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = LocalizationState.recipe_name(recipe.id, recipe.recipe_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = LocalizationState.action_type_name(recipe.action_type)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_font_size_override("font_size", 10)
	match recipe.action_type:
		LabRecipeAction.UPGRADE:
			type_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		LabRecipeAction.LOOP:
			type_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
		LabRecipeAction.INSTANT:
			type_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(type_lbl)

	add_child(panel)

func _draw() -> void:
	if _layout == null:
		return
	for edge in _layout.edges:
		draw_line(edge[0], edge[1], Color(0.65, 0.65, 0.65, 0.7), 1.5)
