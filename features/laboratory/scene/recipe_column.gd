extends Panel

@export var title: String = "":
	set(v):
		title = v
		if is_node_ready():
			$VBox/Header.text = v

@onready var recipe_list: VBoxContainer = $VBox/Scroll/RecipeList

func _ready() -> void:
	$VBox/Header.text = title
