extends ItemEffect
class_name ItemEffectEvolve

@export var youn_data_path: String = ""

func apply(_save: PlayerSaveData) -> void:
	if youn_data_path.is_empty():
		return
	StatsManager.services.life().start_evolution(youn_data_path)
