class_name NarrativeYounCatalog
extends RefCounted

const TypedResourceLoaderScript := preload("res://shared/typed_resource_loader.gd")

## Recursos de Youns usados por secuencias narrativas. Centraliza estas rutas
## para que ceremonia y bienvenida no se desincronicen al mover un recurso.

const PACHAMAMA := "res://data/youns/pachamama.tres"
const NEWEN := "res://data/youns/newen.tres"
const NGURUVILU := "res://data/youns/nguruvilu.tres"

const WELCOME_GUESTS: PackedStringArray = [
	NEWEN,
	NGURUVILU,
	"res://data/youns/luzmala.tres",
	"res://data/youns/tetue.tres",
	"res://data/youns/agumon.tres",
	"res://data/youns/arasy.tres",
	"res://data/youns/kalku.tres",
	"res://data/youns/mboi_tui.tres",
]


static func youn(path: String) -> YounData:
	return TypedResourceLoaderScript.youn(path)


static func pachamama() -> YounData:
	return youn(PACHAMAMA)


static func welcome_guests() -> Array[YounData]:
	var guests: Array[YounData] = []
	for path in WELCOME_GUESTS:
		var data := youn(path)
		if data != null:
			guests.append(data)
	return guests
