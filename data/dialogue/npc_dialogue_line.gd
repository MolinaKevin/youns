class_name NpcDialogueLine
extends Resource

## Clave de LocalizationState.t() — el texto real vive en data/localization/*.json.
@export var key: String = ""
@export var mirrored: bool = false
## Vacío = la dice el hablante por defecto de la conversación. Si se completa
## (path a un YounData), esta línea la dice ese otro personaje — cambio de
## hablante a mitad de charla.
@export_file("*.tres") var youn_data_path: String = ""
