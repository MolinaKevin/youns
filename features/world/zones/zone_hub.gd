extends ZoneBase

func _ready() -> void:
	super._ready()
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	_fix_map_vertex_colors("CityMap")
	_refresh_demo_bridge_visibility()

func _on_lab_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_interior("res://features/world/lab_interior/lab_interior.tscn")

func _on_recipe_completed(recipe: Resource) -> void:
	if recipe.id == "estudio_de_puente_ligero" or recipe.id == "construccion_de_puente":
		_refresh_demo_bridge_visibility()

func _refresh_demo_bridge_visibility() -> void:
	var bridge_researched := LaboratoryState.is_recipe_completed("estudio_de_puente_ligero") \
		or LaboratoryState.is_recipe_completed("construccion_de_puente")
	$DemoRamp.visible = bridge_researched
	$DemoMonzaemon.visible = bridge_researched
	$DemoMonzaemon.set_active(bridge_researched)
