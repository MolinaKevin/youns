extends ItemEffect
class_name ItemEffectForceEmotion

@export var emotion_name: String = ""

func apply(_save: PlayerSaveData, context: ItemEffectContext = null) -> void:
	runtime_context(context).show_emotion(emotion_name)
