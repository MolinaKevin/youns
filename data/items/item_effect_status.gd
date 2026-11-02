extends ItemEffect
class_name ItemEffectStatus

@export var status_key: String = ""
@export var value: bool = false

func apply(save: PlayerSaveData, context: ItemEffectContext = null) -> void:
	if status_key.is_empty() or save == null:
		return
	match status_key:
		"enfermo":
			runtime_context(context).set_sick(value)
		"clock_ui_unlocked":
			save.clock_ui_unlocked = value
		"care_ui_unlocked":
			save.care_ui_unlocked = value
		_:
			push_warning("ItemEffectStatus: status_key desconocido '%s'." % status_key)
