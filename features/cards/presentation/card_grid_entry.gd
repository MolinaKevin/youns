class_name CardGridEntry
extends RefCounted

## Carta suelta en una grilla simple (sin abanico): evolución, reencarnación
## y la lista de reencarnadas repetían el mismo holder dimensionado +
## CardView instanciado + setup(). El llamador decide qué hacer con la vista
## devuelta (deshabilitarla, conectar señales, guardarla).

const CARD_SCENE := preload("res://features/cards/presentation/card_view.tscn")
const CARD_SIZE := Vector2(195.0, 293.0)

static func build(parent: Node, card: CardData, scale: float = 1.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE * scale
	parent.add_child(holder)
	var view: Control = CARD_SCENE.instantiate()
	view.hover_enabled = false
	if scale != 1.0:
		view.scale = Vector2.ONE * scale
	holder.add_child(view)
	view.setup(card)
	return view
