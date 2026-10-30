extends ItemEffect
class_name ItemEffectSetStat

@export var stat_key: String = ""
@export var value: float = 0.0

func apply(_save: PlayerSaveData, context: ItemEffectContext = null) -> void:
	if stat_key.is_empty():
		return
	runtime_context(context).set_stat(stat_key, int(value))
