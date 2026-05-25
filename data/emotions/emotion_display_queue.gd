class_name EmotionDisplayQueue


static func build(active_states: Dictionary, emotions_blocked: bool, sprite_frames: SpriteFrames) -> Array[String]:
	var result: Array[String] = []
	for emotion_name: String in active_states:
		if emotions_blocked and emotion_name != "evolving":
			continue
		if sprite_frames != null and sprite_frames.has_animation(emotion_name):
			result.append(emotion_name)
	return result
