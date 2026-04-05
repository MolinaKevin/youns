extends PanelContainer

signal activate_requested(recipe: Resource)

@onready var fill: ColorRect = $Fill
@onready var name_label = $Content/VBox/TopRow/NameLabel
@onready var time_label = $Content/VBox/TopRow/TimeLabel
@onready var description_label = $Content/VBox/DescriptionLabel
@onready var ingredients_label = $Content/VBox/IngredientsLabel

var _recipe: Resource = null
var _tracking_progress := false
var _shader_mat: ShaderMaterial

const FILL_SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.2, 0.55, 0.2, 0.35);
void fragment() {
	COLOR = UV.x <= progress ? fill_color : vec4(0.0);
}
"""

func _ready() -> void:
	var shader := Shader.new()
	shader.code = FILL_SHADER
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	fill.material = _shader_mat
	_set_fill_color(Color(0.2, 0.55, 0.2, 0.35))

func _set_fill_color(color: Color) -> void:
	_shader_mat.set_shader_parameter("fill_color", color)

func _set_progress(value: float) -> void:
	_shader_mat.set_shader_parameter("progress", value)

func setup(recipe: Resource) -> void:
	_recipe = recipe
	name_label.text = recipe.recipe_name
	description_label.text = recipe.description
	time_label.text = "%.0fs" % recipe.craft_time

	var parts: Array = []
	for ing in recipe.ingredients:
		parts.append("%s x%d" % [ing["id"], ing["amount"]])
	ingredients_label.text = "Necesita: " + ", ".join(parts)

func set_active() -> void:
	_tracking_progress = true
	_set_fill_color(Color(0.2, 0.55, 0.2, 0.35))
	modulate = Color.WHITE

func set_paused(progress: float) -> void:
	_tracking_progress = false
	_set_fill_color(Color(0.6, 0.45, 0.1, 0.35))
	_set_progress(progress)
	modulate = Color(0.85, 0.85, 0.85)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _recipe != null and not _tracking_progress:
			activate_requested.emit(_recipe)

func _process(_delta: float) -> void:
	if not _tracking_progress:
		return
	_set_progress(LaboratoryState.get_current_progress(_recipe.id))
