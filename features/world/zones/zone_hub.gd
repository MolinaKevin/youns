extends ZoneBase

## Receta del lab que construye el puente al oeste del río. El puente no es
## parte del mapa: se agrega al completarla. Hasta entonces BridgeBlocker tapa
## el paso (la grilla de WorldBoundary ya lo deja caminable, ver HUB_BRIDGE).
const RIVER_BRIDGE_RECIPE := "construccion_de_puente"
const RIVER_BRIDGE_SCENE := "res://assets/maps/hub/river_bridge.glb"
const RIVER_BRIDGE_POSITION := Vector3(-33.5, 0, 10)
const CollisionLayers := preload("res://shared/world_collision_layers.gd")

func _ready() -> void:
	super._ready()
	$LabWarp.body_entered.connect(_on_lab_warp_entered)
	LaboratoryState.recipe_completed.connect(_on_recipe_completed)
	LaboratoryState.recipes_loaded.connect(_refresh_river_bridge)
	_fix_map_vertex_colors("CityMap")
	_refresh_demo_bridge_visibility()
	_refresh_river_bridge()
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
	if recipe.id == "estudio_de_puente_ligero" or recipe.id == "construccion_de_puente":
		_refresh_demo_bridge_visibility()
	if recipe.id == RIVER_BRIDGE_RECIPE:
		_refresh_river_bridge()

## Puente del río: se agrega cuando el lab lo construyó; si no, la pared de
## BridgeBlocker impide pasar por donde va a ir.
func _refresh_river_bridge() -> void:
	var built := LaboratoryState.is_recipe_completed(RIVER_BRIDGE_RECIPE)
	$BridgeBlocker/Col.disabled = built
	var bridge := get_node_or_null("RiverBridge")
	if built and bridge == null:
		bridge = (load(RIVER_BRIDGE_SCENE) as PackedScene).instantiate()
		bridge.name = "RiverBridge"
		bridge.position = RIVER_BRIDGE_POSITION
		add_child(bridge)
		CollisionLayers.configure_ground_colliders(bridge)
	elif not built and bridge != null:
		bridge.queue_free()

func _refresh_demo_bridge_visibility() -> void:
	var bridge_researched := LaboratoryState.is_recipe_completed("estudio_de_puente_ligero") \
		or LaboratoryState.is_recipe_completed("construccion_de_puente")
	$DemoMonzaemon.visible = bridge_researched
	$DemoMonzaemon.set_active(bridge_researched)
