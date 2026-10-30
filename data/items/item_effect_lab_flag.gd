class_name ItemEffectLabFlag
extends ItemEffect

## Activa un consumible del laboratorio. Repetirlo consume el objeto pero el
## estado queda igual: los efectos pendientes no se acumulan.
@export_enum("training_progress", "training_time", "biome_sample") var flag := ""

func apply(save: PlayerSaveData, _context: ItemEffectContext = null) -> void:
	match flag:
		"training_progress": save.training_progress_boost_pending = true
		"training_time": save.training_time_compression_pending = true
		"biome_sample": save.biome_sample_guaranteed = true
