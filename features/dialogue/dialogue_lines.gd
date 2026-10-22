class_name DialogueLines
extends RefCounted

## Arma el Dictionary de línea que espera Dialogue.start() a partir de un YounData.
static func line_for(data: YounData, text: String, mirrored := false) -> Dictionary:
	return {
		"speaker": data.youn_name,
		"text": text,
		"portrait": data.portrait,
		"portrait_position": data.dialogue_portrait_position,
		"portrait_scale": data.portrait_scale,
		"nameplate_side": data.dialogue_nameplate_side,
		"mirrored": mirrored,
	}

## Conversación de varias líneas: cada entrada es un texto suelto o un
## Dictionary con "text", "mirrored" y, opcionalmente, "youn_data_path" para
## cambiar de hablante a mitad de la charla.
static func build(default_data: YounData, entries: Array, default_mirrored := false) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for entry: Variant in entries:
		var line_data := default_data
		var line_text := str(entry)
		var line_mirrored := default_mirrored
		if entry is Dictionary:
			line_text = str(entry.get("text", ""))
			line_mirrored = bool(entry.get("mirrored", line_mirrored))
			var youn_data_path := str(entry.get("youn_data_path", ""))
			if not youn_data_path.is_empty():
				var loaded_data := load(youn_data_path) as YounData
				if loaded_data != null:
					line_data = loaded_data
		lines.append(line_for(line_data, line_text, line_mirrored))
	return lines

## Atajo: arma una sola línea y la manda directo a Dialogue.start().
static func say(data: YounData, text: String, mirrored := false) -> void:
	var lines: Array[Dictionary] = [line_for(data, text, mirrored)]
	Dialogue.start(lines)

## Atajo: arma una conversación de varias líneas y la manda a Dialogue.start().
static func say_many(default_data: YounData, entries: Array, default_mirrored := false) -> void:
	Dialogue.start(build(default_data, entries, default_mirrored))
