class_name DialogueLineData
extends RefCounted

## Constructor único para el Dictionary que consume DialogueBox. El formato se
## conserva porque los diálogos editables siguen siendo declarativos.

static func make(data: YounData, text: String, mirrored: bool = false) -> Dictionary:
	return {
		"speaker": data.youn_name,
		"text": text,
		"portrait": data.portrait,
		"portrait_position": data.dialogue_portrait_position,
		"portrait_scale": data.portrait_scale,
		"nameplate_side": data.dialogue_nameplate_side,
		"mirrored": mirrored,
	}
