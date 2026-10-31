class_name WorldRewardService
extends RefCounted

## Recompensas que vienen del mundo (NPCs, exploración, eventos), separadas de
## las recompensas que se obtienen al completar una receta en el laboratorio.
## Ambas usan por ahora la misma notificación flotante.

static func grant_mission(mission_id: String, title_key: String) -> bool:
	var save := PlayerSessionAccess.save()
	if save == null or mission_id.is_empty() or save.world_progress.has_mission(mission_id):
		return false
	save.world_progress.start_mission(mission_id)
	_notify(LocalizationState.t("world_reward.mission", [LocalizationState.t(title_key)]))
	return true


static func grant_recipe(recipe_id: String) -> bool:
	if PlayerSessionAccess.save() == null or recipe_id.is_empty() or LaboratoryState.is_recipe_unlocked(recipe_id):
		return false
	LaboratoryState.unlock_recipe(recipe_id)
	var recipe := LaboratoryState.get_recipe_by_id(recipe_id)
	var fallback: String = recipe_id
	if recipe != null:
		fallback = str(recipe.recipe_name)
	var recipe_name: String = LocalizationState.recipe_name(recipe_id, fallback)
	_notify(LocalizationState.t("world_reward.recipe", [recipe_name]))
	return true


static func _notify(text: String) -> void:
	GlobalHUD.show_toast(text)
