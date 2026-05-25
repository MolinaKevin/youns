extends ItemEffect
class_name ItemEffectEvolve

@export var youn_data_path: String = ""

func apply(save: PlayerSaveData) -> void:
	if youn_data_path.is_empty():
		return
	StatsManager.start_evolution(youn_data_path)
