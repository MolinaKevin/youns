extends ItemEffect
class_name ItemEffectForceEmotion

@export var emotion_name: String = ""

func apply(_save: PlayerSaveData) -> void:
	StatsManager.clear_emotion(emotion_name)
	StatsManager.show_emotion(emotion_name)
