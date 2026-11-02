class_name TallGrassGuide
extends WorldRouteGuard

func _init() -> void:
	key_prefix = "tall_grass_guide"
	item_received_key = "tool_received"
	item_id = "desbrozadora_de_resonancia"
	mission_id = "clear_tall_grass"
	mission_label_key = "mission.clear_tall_grass"
	recipe_id = "ensamblar_desbrozadora_de_resonancia"
	is_open = func() -> bool:
		var p := _progress()
		return p != null and p.tall_grass_route_open
	open_route = func() -> void:
		var p := _progress()
		if p != null:
			p.tall_grass_route_open = true
	mission_started = func() -> bool:
		var p := _progress()
		return p != null and p.tall_grass_mission_started
	start_mission = func() -> void:
		var p := _progress()
		if p != null:
			p.tall_grass_mission_started = true


func _progress() -> WorldProgressData:
	var save := PlayerSessionAccess.save()
	return save.world_progress if save != null else null
