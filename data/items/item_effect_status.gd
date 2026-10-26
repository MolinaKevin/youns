extends ItemEffect
class_name ItemEffectStatus

@export var status_key: String = ""
@export var value: bool = false

func apply(save: PlayerSaveData) -> void:
	if status_key.is_empty() or save == null:
		return
	match status_key:
		"enfermo":
			StatsManager.set_enfermo(value)
		_:
			if _save_has_property(save, status_key):
				save.set(status_key, value)


func _save_has_property(save: PlayerSaveData, property_name: String) -> bool:
	for property: Dictionary in save.get_property_list():
		if property.get("name", "") == property_name:
			return true
	return false
