extends ZoneBase

func _ready() -> void:
	super._ready()
	_fix_map_vertex_colors("PraderaDerecha")
	$TallGrassGuide.route_opened.connect(refresh_tall_grass_route)
	$TallGrassWarning.body_entered.connect(_on_tall_grass_warning_body_entered)
	refresh_tall_grass_route()

func refresh_tall_grass_route() -> void:
	WorldRouteGate.refresh($TallGrassBarrier, $TallGrassWarning, $TallGrassGuide, _tall_grass_open())

func _on_tall_grass_warning_body_entered(body: Node3D) -> void:
	if body == PartyManager.player and not _tall_grass_open():
		$TallGrassGuide.warn_route_blocked()

func _tall_grass_open() -> bool:
	var save := PlayerSessionAccess.save()
	return save != null and save.world_progress != null and save.world_progress.tall_grass_route_open
