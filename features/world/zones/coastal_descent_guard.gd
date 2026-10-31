class_name CoastalDescentGuard
extends WorldYoun

## NPC temporal de la bajada a la playa. El modelo es un placeholder hasta que
## exista el visual de la guardacostas; la misión y la barrera ya son funcionales.

signal coastal_descent_opened

const CABLE_ITEM_ID := "cable_de_descenso_costero"
const InventoryServiceScript := preload("res://shared/inventory_service.gd")
const WorldRewardServiceScript := preload("res://shared/world_reward_service.gd")

func begin_encounter() -> void:
	_talk(false)


func warn_descent_blocked() -> void:
	if Dialogue.is_busy() or is_engaging_combat():
		return
	_talk(true)


func _talk(from_barrier: bool) -> void:
	var progress := _progress()
	if progress == null:
		return
	if progress.coastal_descent_open:
		_play_lines(["world.coastal_guard.open"])
		return
	if _has_cable():
		_consume_cable()
		progress.coastal_descent_open = true
		coastal_descent_opened.emit()
		_play_lines(["world.coastal_guard.cable_received"])
		return
	if not progress.coastal_descent_mission_started:
		progress.coastal_descent_mission_started = true
		WorldRewardServiceScript.grant_mission("secure_coastal_descent", "mission.secure_coastal_descent")
		WorldRewardServiceScript.grant_recipe("ensamblar_cable_de_descenso_costero")
		_play_lines([
			"world.coastal_guard.greeting",
			"world.coastal_guard.blocked",
			"world.coastal_guard.mission",
		])
		return
	_play_lines(["world.coastal_guard.reminder" if from_barrier else "world.coastal_guard.reminder_talk"])


func _play_lines(keys: Array[String]) -> void:
	prepare_encounter()
	Dialogue.dialogue_finished.connect(finish_non_combat_encounter, CONNECT_ONE_SHOT)
	var lines: Array[String] = []
	for key in keys:
		lines.append(LocalizationState.t(key))
	DialogueLines.say_many(youn_data, lines)


func _progress() -> WorldProgressData:
	var save := PlayerSessionAccess.save()
	return save.world_progress if save != null else null


func _has_cable() -> bool:
	var save := PlayerSessionAccess.save()
	if save == null:
		return false
	return save.inventory_items.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == CABLE_ITEM_ID)


func _consume_cable() -> void:
	var save := PlayerSessionAccess.save()
	if save == null:
		return
	for index in save.inventory_items.size():
		if str(save.inventory_items[index].get("id", "")) == CABLE_ITEM_ID:
			InventoryServiceScript.consume_from_save(save, index)
			return
