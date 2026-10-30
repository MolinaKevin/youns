extends ItemEffect
class_name ItemEffectEvolve

@export var youn_data_path: String = ""

func apply(_save: PlayerSaveData, context: ItemEffectContext = null) -> void:
	if youn_data_path.is_empty():
		return
	runtime_context(context).start_evolution(youn_data_path)
