class_name LaboratoryRewardService
extends RefCounted

## Aplica recompensas del laboratorio sin mezclar sus reglas con el ciclo de
## carga, temporizadores y progreso de LaboratoryState.

const LabRewardScript := preload("res://data/lab_reward.gd")
const ItemCatalogScript := preload("res://shared/item_catalog.gd")

var _state
var _sync_hud: Callable

func _init(state, sync_hud: Callable = Callable()) -> void:
	_state = state
	_sync_hud = sync_hud

func grant(reward: Dictionary) -> void:
	var save: PlayerSaveData = _state.progress().save()
	if save == null:
		return
	match LabRewardScript.type_of(reward):
		LabRewardScript.UNLOCK_RECIPE:
			_state.unlock_recipe(reward["id"])
		LabRewardScript.UNLOCK_CLOCK_UI:
			save.clock_ui_unlocked = true
			if _sync_hud.is_valid():
				_sync_hud.call()
		LabRewardScript.UNLOCK_CARE_UI:
			save.care_ui_unlocked = true
			if _sync_hud.is_valid():
				_sync_hud.call()
		LabRewardScript.ITEM:
			_grant_item(reward)
		LabRewardScript.WORLD_BRIDGE:
			save.world_progress.unlock_construction(str(reward.get("id", "")))
		LabRewardScript.YOUN_GROWTH_BONUS:
			save.lab_youn_growth_bonus += maxi(0, int(reward.get("value", 0)))
		LabRewardScript.MATERIAL_PRODUCTION:
			_state.add_output_item("datos", LocalizationState.item_name("datos", "datos"), reward.get("value", 1), 99)
			_state.check_indirect_unlocks("datos")
		LabRewardScript.MAX_HP:
			save.lab_max_hp_bonus += maxi(0, int(reward.get("value", 0)))
		LabRewardScript.LAB_EFFICIENCY:
			save.lab_data_per_cycle = maxi(save.lab_data_per_cycle, int(reward.get("data_per_cycle", 1)))
			save.lab_data_cost_reduction = maxf(save.lab_data_cost_reduction, float(reward.get("data_cost_reduction", 0.0)))
		LabRewardScript.COMBAT_RECOVERY:
			save.lab_combat_recovery_percent = maxf(save.lab_combat_recovery_percent, float(reward.get("value", 0.0)))

func _grant_item(reward: Dictionary) -> void:
	var item_id: String = reward["id"]
	var item_recipe: LabRecipe = _state.get_recipe_by_id(item_id)
	var item_name: String = item_recipe.item_name if item_recipe and item_recipe.item_name != "" else item_id
	if item_recipe and item_name == item_id:
		item_name = item_recipe.recipe_name
	var item_data := ItemCatalogScript.by_id(item_id)
	if item_data:
		item_name = item_data.name
	var amount := int(reward.get("amount", 1))
	if item_id == "datos":
		amount *= _state.progress().save().lab_data_per_cycle
	_state.add_output_item(item_id, item_name, amount, int(reward.get("limit", 99)))
	if item_data:
		_state.set_output_data_path(item_id, item_data.resource_path)
	_state.check_indirect_unlocks(item_id)
