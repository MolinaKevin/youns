class_name TallGrassGuide
extends WorldYoun

signal tall_grass_route_opened

const DESBROZADORA_ITEM_ID := "desbrozadora_de_resonancia"
const InventoryServiceScript := preload("res://shared/inventory_service.gd")
const WorldRewardServiceScript := preload("res://shared/world_reward_service.gd")

func begin_encounter() -> void:
	_talk(false)


func warn_tall_grass_blocked() -> void:
	if Dialogue.is_busy() or is_engaging_combat():
		return
	_talk(true)


func _talk(from_barrier: bool) -> void:
	var save := PlayerSessionAccess.save()
	if save == null:
		return
	if save.world_progress.tall_grass_route_open:
		_play_lines(["world.tall_grass_guide.open"])
		return
	if _has_desbrozadora(save):
		_consume_desbrozadora(save)
		save.world_progress.tall_grass_route_open = true
		tall_grass_route_opened.emit()
		_play_lines(["world.tall_grass_guide.tool_received"])
		return
	if not save.world_progress.tall_grass_mission_started:
		save.world_progress.tall_grass_mission_started = true
		WorldRewardServiceScript.grant_mission("clear_tall_grass", "mission.clear_tall_grass")
		WorldRewardServiceScript.grant_recipe("ensamblar_desbrozadora_de_resonancia")
		_play_lines([
			"world.tall_grass_guide.greeting",
			"world.tall_grass_guide.blocked",
			"world.tall_grass_guide.mission",
		])
		return
	_play_lines(["world.tall_grass_guide.reminder" if from_barrier else "world.tall_grass_guide.reminder_talk"])


func _play_lines(keys: Array[String]) -> void:
	prepare_encounter()
	Dialogue.dialogue_finished.connect(finish_non_combat_encounter, CONNECT_ONE_SHOT)
	var lines: Array[String] = []
	for key in keys:
		lines.append(LocalizationState.t(key))
	DialogueLines.say_many(youn_data, lines)


func _has_desbrozadora(save: PlayerSaveData) -> bool:
	return save.inventory_items.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == DESBROZADORA_ITEM_ID)


func _consume_desbrozadora(save: PlayerSaveData) -> void:
	for index in save.inventory_items.size():
		if str(save.inventory_items[index].get("id", "")) == DESBROZADORA_ITEM_ID:
			InventoryServiceScript.consume_from_save(save, index)
			return
