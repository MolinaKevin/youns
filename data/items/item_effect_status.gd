extends ItemEffect
class_name ItemEffectStatus

@export var status_key: String = ""
@export var value: bool = false

func apply(save: PlayerSaveData) -> void:
	if status_key.is_empty():
		return
	match status_key:
		"enfermo":
			StatsManager.set_enfermo(value)
		_:
			save.set(status_key, value)
