class_name EmotionAssetsValidator
extends RefCounted

func missing_animations(frames: SpriteFrames, required: PackedStringArray) -> PackedStringArray:
	var missing := PackedStringArray()
	if frames == null:
		return required
	for animation in required:
		if not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
			missing.append(animation)
	return missing
