class_name CoastalDescentGuard
extends WorldRouteGuard

## NPC temporal de la bajada a la playa. El modelo es un placeholder hasta que
## exista el visual de la guardacostas; la misión y la barrera ya son funcionales.

func _init() -> void:
	key_prefix = "coastal_guard"
	item_received_key = "cable_received"
	item_id = "cable_de_descenso_costero"
	mission_id = "secure_coastal_descent"
	mission_label_key = "mission.secure_coastal_descent"
	recipe_id = "ensamblar_cable_de_descenso_costero"
	is_open = func() -> bool:
		var p := _progress()
		return p != null and p.coastal_descent_open
	open_route = func() -> void:
		var p := _progress()
		if p != null:
			p.coastal_descent_open = true
	mission_started = func() -> bool:
		var p := _progress()
		return p != null and p.coastal_descent_mission_started
	start_mission = func() -> void:
		var p := _progress()
		if p != null:
			p.coastal_descent_mission_started = true


func _progress() -> WorldProgressData:
	var save := PlayerSessionAccess.save()
	return save.world_progress if save != null else null
