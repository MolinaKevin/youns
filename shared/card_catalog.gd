class_name CardCatalog
extends RefCounted

## Catálogo canónico de cartas editables. Descubre los .tres del directorio
## para que agregar una carta no requiera mantener una lista paralela en código.

const CARDS_DIR := "res://data/cards"
static var _cards: Array[CardData] = []
static var _loaded := false


static func load_all() -> Array[CardData]:
	if _loaded:
		return _cards
	_loaded = true
	for resource in ResourceCatalogLoader.resources(CARDS_DIR, CardData):
		_cards.append(resource as CardData)
	return _cards


static func known_ids() -> Dictionary:
	var ids := {}
	for card in load_all():
		if not card.id.is_empty():
			ids[card.id] = true
	return ids


static func filter_known_ids(ids: Array[String], label: String) -> Array[String]:
	var known := known_ids()
	var valid: Array[String] = []
	for card_id in ids:
		if known.has(card_id):
			valid.append(card_id)
		else:
			push_error("CardCatalog: id inexistente '%s' en %s." % [card_id, label])
	return valid
