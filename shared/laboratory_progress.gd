class_name LaboratoryProgress
extends RefCounted

## Fachada mínima del progreso persistido del laboratorio. Evita que las
## reglas de recetas y recompensas naveguen GameState.save_service por su
## cuenta y facilita usarlas con una partida de prueba.

var _save_provider: Callable

func _init(save_provider: Callable) -> void:
	_save_provider = save_provider

func save() -> PlayerSaveData:
	return _save_provider.call() as PlayerSaveData if _save_provider.is_valid() else null

func has_gold(amount: int) -> bool:
	var player_save := save()
	return player_save != null and player_save.gold >= amount

func spend_gold(amount: int) -> void:
	var player_save := save()
	if player_save != null and amount > 0:
		player_save.gold = max(0, player_save.gold - amount)

func is_unlocked(recipe_id: String) -> bool:
	var player_save := save()
	return player_save != null and player_save.unlocked_recipe_ids.has(recipe_id)

func unlock(recipe_id: String) -> bool:
	var player_save := save()
	if player_save == null or player_save.unlocked_recipe_ids.has(recipe_id):
		return false
	player_save.unlocked_recipe_ids.append(recipe_id)
	return true

func is_completed(recipe_id: String) -> bool:
	var player_save := save()
	return player_save != null and player_save.completed_recipe_ids.has(recipe_id)

func complete(recipe_id: String) -> bool:
	var player_save := save()
	if player_save == null or player_save.completed_recipe_ids.has(recipe_id):
		return false
	player_save.completed_recipe_ids.append(recipe_id)
	return true
