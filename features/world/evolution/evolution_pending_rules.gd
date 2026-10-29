class_name EvolutionPendingRules
extends RefCounted

## Reglas puras de finalización de una evolución. La pantalla sólo conserva el
## estado de selección y se ocupa de renderizarlo.

static func pending_colors(remaining_colors: Dictionary) -> int:
	var total := 0
	for id in remaining_colors:
		total += remaining_colors[id]
	return total

static func pending_lines(deck: Array[CardData], used_lines: Array[bool]) -> int:
	var has_room := deck.any(func(card: CardData) -> bool:
		return DeckRules.can_add_line(card.top) or DeckRules.can_add_line(card.bottom))
	if not has_room:
		return 0
	return used_lines.count(false)

static func can_finish(remaining_colors: Dictionary, deck: Array[CardData], used_lines: Array[bool]) -> bool:
	return pending_colors(remaining_colors) == 0 and pending_lines(deck, used_lines) == 0
