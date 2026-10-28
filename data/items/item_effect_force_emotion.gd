extends ItemEffect
class_name ItemEffectForceEmotion

@export var emotion_name: String = ""

func apply(_save: PlayerSaveData) -> void:
	StatsManager.services.emotions().show(emotion_name)
