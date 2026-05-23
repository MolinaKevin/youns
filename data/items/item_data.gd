extends Resource
class_name ItemData

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var icon: Texture2D
@export var effects: Array[ItemEffect] = []
@export_range(0.0, 10.0, 0.1) var weight_gain: float = 0.0
@export_range(0.0, 10.0, 0.1) var poop_size: float = 0.0

func apply_effects(save: PlayerSaveData) -> void:
	for effect in effects:
		effect.apply(save)
	if weight_gain > 0.0:
		StatsManager.add_weight(weight_gain)
	if poop_size > 0.0:
		save.poop_pending += poop_size
	StatsManager.check_status()

func to_inventory_entry(count: int = 1) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"icon": icon.resource_path if icon else "",
		"data_path": resource_path,
		"count": count,
	}
