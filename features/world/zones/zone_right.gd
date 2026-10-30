extends ZoneBase

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("PraderaDerecha")
	$TallGrassGuide.tall_grass_route_opened.connect(refresh_tall_grass_route)
	$TallGrassWarning.body_entered.connect(_on_tall_grass_warning_body_entered)
	refresh_tall_grass_route()

func refresh_tall_grass_route() -> void:
	var progress := GameState.save_service.player_save.world_progress if GameState.save_service.player_save else null
	var open := progress != null and progress.tall_grass_route_open
	$TallGrassBarrier/Col.disabled = open
	$TallGrassBarrier.visible = not open
	$TallGrassWarning.monitoring = not open
	$TallGrassGuide.visible = not open
	$TallGrassGuide.set_active(not open)

func _on_tall_grass_warning_body_entered(body: Node3D) -> void:
	if body == PartyManager.player:
		$TallGrassGuide.warn_tall_grass_blocked()
