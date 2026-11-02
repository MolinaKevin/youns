class_name WorldRouteGuard
extends WorldYoun

## NPC que bloquea una ruta hasta que el jugador consigue un ítem (ver
## CoastalDescentGuard/TallGrassGuide). La secuencia de diálogo es siempre la
## misma: "ya está abierta" / "tengo el ítem, la abro" / "primera vez, doy la
## misión" / "recordatorio" — cada guardia solo declara su ítem, su misión y
## las claves de diálogo (todas bajo "world.<key_prefix>.*").
##
## El flag de progreso vive en WorldProgressData y cada subclase expone su
## lectura/escritura como Callable en vez de nombrarlo como string: así un
## guardia no puede pisar un campo de WorldProgressData por error de tipeo.

signal route_opened

const InventoryServiceScript := preload("res://shared/inventory_service.gd")
const WorldRewardServiceScript := preload("res://shared/world_reward_service.gd")

var key_prefix := ""
## Sufijo de la clave cuando se entrega el ítem: "world.<key_prefix>.<item_received_key>".
var item_received_key := ""
var item_id := ""
var mission_id := ""
var mission_label_key := ""
var recipe_id := ""

## () -> bool
var is_open := func() -> bool: return false
## () -> void: marca la ruta abierta en WorldProgressData.
var open_route := func() -> void: pass
## () -> bool
var mission_started := func() -> bool: return false
## () -> void: marca la misión iniciada en WorldProgressData.
var start_mission := func() -> void: pass


func begin_encounter() -> void:
	_talk(false)


func warn_route_blocked() -> void:
	if Dialogue.is_busy() or is_engaging_combat():
		return
	_talk(true)


func _talk(from_barrier: bool) -> void:
	var save := PlayerSessionAccess.save()
	if save == null:
		return
	if is_open.call():
		_play_lines(["world.%s.open" % key_prefix])
		return
	if _has_item(save):
		_consume_item(save)
		open_route.call()
		route_opened.emit()
		_play_lines(["world.%s.%s" % [key_prefix, item_received_key]])
		return
	if not mission_started.call():
		start_mission.call()
		WorldRewardServiceScript.grant_mission(mission_id, mission_label_key)
		WorldRewardServiceScript.grant_recipe(recipe_id)
		_play_lines([
			"world.%s.greeting" % key_prefix,
			"world.%s.blocked" % key_prefix,
			"world.%s.mission" % key_prefix,
		])
		return
	_play_lines(["world.%s.reminder" % key_prefix if from_barrier else "world.%s.reminder_talk" % key_prefix])


func _play_lines(keys: Array[String]) -> void:
	prepare_encounter()
	Dialogue.dialogue_finished.connect(finish_non_combat_encounter, CONNECT_ONE_SHOT)
	var lines: Array[String] = []
	for key in keys:
		lines.append(LocalizationState.t(key))
	DialogueLines.say_many(youn_data, lines)


func _has_item(save: PlayerSaveData) -> bool:
	return save.inventory_items.any(func(entry: Dictionary) -> bool: return str(entry.get("id", "")) == item_id)


func _consume_item(save: PlayerSaveData) -> void:
	for index in save.inventory_items.size():
		if str(save.inventory_items[index].get("id", "")) == item_id:
			InventoryServiceScript.consume_from_save(save, index)
			return
