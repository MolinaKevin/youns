class_name LaboratoryRewardService
extends RefCounted

## Aplica recompensas del laboratorio sin mezclar sus reglas con el ciclo de
## carga, temporizadores y progreso de LaboratoryState.

const LabRewardScript := preload("res://data/lab_reward.gd")
const ItemCatalogScript := preload("res://shared/item_catalog.gd")

var _state

func _init(state) -> void:
	_state = state

func grant(reward: Dictionary) -> void:
	if GameState.save_service.player_save == null:
		return
	match LabRewardScript.type_of(reward):
		LabRewardScript.UNLOCK_RECIPE:
			_state.unlock_recipe(reward["id"])
		LabRewardScript.UNLOCK_CLOCK_UI:
			GameState.save_service.player_save.clock_ui_unlocked = true
			GlobalHUD.sync_overworld_ui_visibility()
		LabRewardScript.UNLOCK_CARE_UI:
			GameState.save_service.player_save.care_ui_unlocked = true
			GlobalHUD.sync_overworld_ui_visibility()
		LabRewardScript.ITEM:
			_grant_item(reward)
		LabRewardScript.WORLD_BRIDGE:
			GameState.save_service.player_save.world_progress.unlock_construction(str(reward.get("id", "")))
		LabRewardScript.YOUN_GROWTH_BONUS:
			GameState.save_service.player_save.lab_youn_growth_bonus += maxi(0, int(reward.get("value", 0)))
		LabRewardScript.MATERIAL_PRODUCTION:
			_state.add_output_item("datos", LocalizationState.item_name("datos", "datos"), reward.get("value", 1), 99)
			_state.check_indirect_unlocks("datos")
		LabRewardScript.MAX_HP:
			GameState.save_service.player_save.lab_max_hp_bonus += maxi(0, int(reward.get("value", 0)))
		LabRewardScript.LAB_EFFICIENCY:
			var save := GameState.save_service.player_save
			save.lab_data_per_cycle = maxi(save.lab_data_per_cycle, int(reward.get("data_per_cycle", 1)))
			save.lab_data_cost_reduction = maxf(save.lab_data_cost_reduction, float(reward.get("data_cost_reduction", 0.0)))
		LabRewardScript.COMBAT_RECOVERY:
			GameState.save_service.player_save.lab_combat_recovery_percent = maxf(GameState.save_service.player_save.lab_combat_recovery_percent, float(reward.get("value", 0.0)))

func _grant_item(reward: Dictionary) -> void:
	var item_id: String = reward["id"]
	var item_recipe: Resource = _state.get_recipe_by_id(item_id)
	var item_name: String = item_recipe.item_name if item_recipe and item_recipe.item_name != "" else item_id
	if item_recipe and item_name == item_id:
		item_name = item_recipe.recipe_name
	var item_data := ItemCatalogScript.by_id(item_id)
	if item_data:
		item_name = item_data.name
	var amount := int(reward.get("amount", 1))
	if item_id == "datos":
		amount *= GameState.save_service.player_save.lab_data_per_cycle
	_state.add_output_item(item_id, item_name, amount, int(reward.get("limit", 99)))
	if item_data and _state.pending_output.has(item_id):
		_state.pending_output[item_id]["data_path"] = item_data.resource_path
	_state.check_indirect_unlocks(item_id)
