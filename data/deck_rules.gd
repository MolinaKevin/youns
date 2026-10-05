class_name DeckRules
extends RefCounted

## Reglas del mazo de la partida (PlayerSaveData.deck): copias propias de las
## cartas que las evoluciones modifican.

const Intelligences := preload("res://data/youns/intelligences.gd")

## Máximo absoluto de líneas en una mitad (el tope del ultimate).
const MAX_LINES_PER_HALF := 5

## Cuántas líneas de una mitad puede usar el Youn por jugada, según su etapa.
## Las elige el jugador en combate, siempre hacia adelante (ver combat.gd).
const LINE_CAP_BY_STAGE := {
	"bebe": 1, "nino": 2, "adolescente": 3, "campeon": 4, "ultimate": 5,
}

static func line_cap(stage: String) -> int:
	return LINE_CAP_BY_STAGE.get(stage, MAX_LINES_PER_HALF)

## Si la partida todavía no tiene mazo propio, lo arma con copias de las cartas
## de equipped_deck_ids.
static func ensure_deck(save: PlayerSaveData) -> void:
	if save == null or not save.deck.is_empty():
		return
	for card in CardDatabase.get_cards_from_ids(save.equipped_deck_ids):
		save.deck.append(card.clone())

## Las cartas del mazo de la partida (armándolo si hace falta).
static func cards(save: PlayerSaveData) -> Array[CardData]:
	ensure_deck(save)
	return save.deck if save != null else ([] as Array[CardData])

## Agrega al mazo una copia de la carta.
static func add_card(save: PlayerSaveData, card: CardData) -> CardData:
	if save == null or card == null:
		return null
	ensure_deck(save)
	var copy := card.clone()
	save.deck.append(copy)
	return copy

## Cambia la mitad a una inteligencia: su color pasa a ser el de esa inteligencia.
static func recolor(action: CardAction, intelligence: String) -> void:
	if action == null:
		return
	action.intelligence = intelligence
	action.color = Intelligences.half_color(intelligence)

static func can_add_line(action: CardAction) -> bool:
	return action != null and action.lines.size() < MAX_LINES_PER_HALF

## Agrega al final de la mitad una copia de la línea. false si ya está llena.
static func add_line(action: CardAction, line: CardActionLine) -> bool:
	if not can_add_line(action) or line == null:
		return false
	action.lines.append(line.duplicate())
	return true
