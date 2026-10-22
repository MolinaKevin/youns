class_name NpcDialogue
extends Resource

## Una conversación: lista de líneas en orden (ver NpcDialogueLine). El texto
## real vive en data/localization/*.json, acá solo se guarda qué claves, en
## qué orden, y con qué mirrored/hablante cada una.
@export var lines: Array[NpcDialogueLine] = []
## Vacío = al terminar las líneas no pasa nada más. Si tiene opciones, al
## terminar se abre un menú (Dialogue.ask) con ellas (ver NpcChoice).
@export var choices: Array[NpcChoice] = []

## Arma el Array[Dictionary] que espera DialogueLines.say_many()/build().
func to_entries() -> Array:
	var entries: Array = []
	for line in lines:
		var entry := {
			"text": LocalizationState.t(line.key),
			"mirrored": line.mirrored,
		}
		if not line.youn_data_path.is_empty():
			entry["youn_data_path"] = line.youn_data_path
		entries.append(entry)
	return entries
