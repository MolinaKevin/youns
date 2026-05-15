extends ItemEffect
class_name ItemEffectSetStat

@export var stat_key: String = ""
@export var value: float = 0.0

func apply(_save: PlayerSaveData) -> void:
	if stat_key.is_empty():
		return
	StatsManager.set_stat(stat_key, int(value))
