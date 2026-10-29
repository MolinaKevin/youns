class_name LaboratoryRewardService
extends RefCounted

## Aplica recompensas del laboratorio sin mezclar sus reglas con el ciclo de
## carga, temporizadores y progreso de LaboratoryState.

const LabReward := preload("res://data/lab_reward.gd")

var _state

func _init(state) -> void:
	_state = state

func grant(reward: Dictionary) -> void:
	if GameState.save_service.player_save == null:
		return
	match LabReward.type_of(reward):
		LabReward.UNLOCK_RECIPE:
			_state.unlock_recipe(reward["id"])
		LabReward.UNLOCK_CLOCK_UI:
			GameState.save_service.player_save.clock_ui_unlocked = true
			GlobalHUD.sync_overworld_ui_visibility()
		LabReward.UNLOCK_CARE_UI:
			GameState.save_service.player_save.care_ui_unlocked = true
			GlobalHUD.sync_overworld_ui_visibility()
		LabReward.ITEM:
			_grant_item(reward)
		LabReward.WORLD_BRIDGE:
			GameState.save_service.player_save.world_progress.unlock_construction(str(reward.get("id", "")))
		LabReward.YOUN_GROWTH_BONUS:
			GameState.save_service.player_save.lab_youn_growth_bonus += maxi(0, int(reward.get("value", 0)))
		LabReward.MATERIAL_PRODUCTION:
			_state.add_output_item("datos", LocalizationState.item_name("datos", "datos"), reward.get("value", 1), 99)
			_state.check_indirect_unlocks("datos")
		LabReward.MAX_HP:
			GameState.save_service.player_save.lab_max_hp_bonus += maxi(0, int(reward.get("value", 0)))

func _grant_item(reward: Dictionary) -> void:
	var item_id: String = reward["id"]
	var item_recipe: Resource = _state.get_recipe_by_id(item_id)
	var item_name: String = item_recipe.item_name if item_recipe and item_recipe.item_name != "" else item_id
	if item_recipe and item_name == item_id:
		item_name = item_recipe.recipe_name
	_state.add_output_item(item_id, item_name, reward.get("amount", 1), 99)
	_state.check_indirect_unlocks(item_id)
