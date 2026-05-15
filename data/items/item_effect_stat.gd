extends ItemEffect
class_name ItemEffectStat

@export var stat_key: String = ""
@export var delta: float = 0.0

func apply(_save: PlayerSaveData) -> void:
	if stat_key.is_empty():
		return
	StatsManager.add_stat(stat_key, int(delta))
