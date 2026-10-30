extends ZoneBase

const CollisionLayers := preload("res://shared/world_collision_layers.gd")
const LabMilestoneScript := preload("res://data/lab_milestone.gd")
const WorldConstructionData := preload("res://data/world/world_construction.gd")
const WorldConstructionCatalogScript := preload("res://data/world/world_construction_catalog.gd")

var _construction_catalog := WorldConstructionCatalogScript.new()

func _ready() -> void:
	super._ready()
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	call_deferred("_refresh_after_laboratory_load")
	_fix_map_vertex_colors("CityMap")
	_refresh_demo_bridge_visibility()
	_refresh_constructions()
	refresh_north_trail()

## Sendero norte al crossroads (ver ZoneManager.north_trail_open): cerrado,
## se ven los árboles NorthTrailTrees (con sus colisiones) y NorthTrailBlocker
## tapa el paso; abierto, desaparecen los dos. El resto del bosque entre el
## hub y el crossroads (NorthForest) queda siempre.
func refresh_north_trail() -> void:
	var open: bool = ZoneManager.north_trail_open
	$NorthTrailBlocker/Col.disabled = open
	var trees := $CityMap.find_child("NorthTrailTrees", true, false) as Node3D
	if trees == null:
		push_warning("ZoneHub: falta NorthTrailTrees en city_map.glb")
		return
	trees.visible = not open
	for col in trees.find_children("*", "CollisionShape3D", true, false):
		(col as CollisionShape3D).disabled = open

func _on_lab_warp_entered(body: Node3D) -> void:
	if body.name == "Player":
		ZoneManager.enter_interior("res://features/world/lab_interior/lab_interior.tscn")

func _on_recipe_completed(recipe: Resource) -> void:
	if recipe.id == LabMilestoneScript.BRIDGE_STUDY or recipe.id == LabMilestoneScript.RIVER_BRIDGE:
		_refresh_demo_bridge_visibility()
	_refresh_constructions()

func _refresh_after_laboratory_load() -> void:
	await LaboratoryState.ensure_loaded()
	_refresh_constructions()

## Aplica las estructuras declaradas para esta zona. Cada construcción puede
## aportar escena, posición y un collider que se desactiva al desbloquearse.
func _refresh_constructions() -> void:
	for construction in _construction_catalog.for_zone(zone_id):
		_refresh_construction(construction)


func _refresh_construction(construction: WorldConstructionData) -> void:
	var progress := GameState.save_service.player_save.world_progress if GameState.save_service.player_save else null
	var built := progress != null and progress.has_construction(construction.id)
	var blocker := get_node_or_null(construction.blocker_path) as CollisionShape3D
	if blocker != null:
		blocker.disabled = built
	var node := get_node_or_null(construction.node_name)
	if built and node == null:
		var scene := load(construction.scene_path) as PackedScene
		if scene == null:
			push_error("ZoneHub: no se pudo cargar construcción '%s'." % construction.id)
			return
		node = scene.instantiate()
		node.name = construction.node_name
		(node as Node3D).position = construction.position
		add_child(node)
		CollisionLayers.configure_ground_colliders(node)
	elif not built and node != null:
		node.queue_free()

func _refresh_demo_bridge_visibility() -> void:
	var bridge_researched := LaboratoryState.is_recipe_completed(LabMilestoneScript.BRIDGE_STUDY) \
		or LaboratoryState.is_recipe_completed(LabMilestoneScript.RIVER_BRIDGE)
	$DemoMonzaemon.visible = bridge_researched
	$DemoMonzaemon.set_active(bridge_researched)
