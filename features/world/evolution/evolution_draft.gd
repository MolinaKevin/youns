class_name EvolutionDraft
extends RefCounted

## Estado puro de las decisiones que toma el jugador durante una evolución.
## No conoce nodos ni presentación: la pantalla sólo lo dibuja y delega aquí
## los cambios para que las reglas puedan probarse sin montar la UI.

const PendingRules := preload("res://features/world/evolution/evolution_pending_rules.gd")

enum Section { STATS, COLORS, CARDS, ACTIONS }

var to: YounData
var deck: Array[CardData] = []
var section := Section.STATS
var remaining_colors: Dictionary = {}
var used_lines: Array[bool] = []
var selected_color := ""
var selected_line := -1
var history: Array[Dictionary] = []


func _init(target: YounData, cards: Array[CardData]) -> void:
	to = target
	deck.assign(cards)
	if to == null:
		return
	for id in to.color_changes:
		remaining_colors[id] = to.color_changes[id]
	used_lines.resize(to.granted_lines.size())
	used_lines.fill(false)


func show_section(next_section: int) -> void:
	section = next_section
	selected_color = ""
	selected_line = -1


func select_color(id: String) -> bool:
	if section != Section.COLORS or remaining_colors.get(id, 0) <= 0:
		return false
	selected_color = id
	return true


func clear_color_selection() -> void:
	selected_color = ""


func select_line(index: int) -> bool:
	if section != Section.ACTIONS or index < 0 or index >= used_lines.size() or used_lines[index]:
		return false
	selected_line = index
	return true


func clear_line_selection() -> void:
	selected_line = -1


## Devuelve "" al aplicar o una causa localizada por la UI (half_full).
func apply_to_half(card: CardData, is_top: bool) -> String:
	var action: CardAction = card.top if is_top else card.bottom
	if action == null:
		return "invalid_half"
	if section == Section.COLORS and selected_color != "" and remaining_colors.get(selected_color, 0) > 0:
		history.append({"type": "color", "action": action,
			"prev_intelligence": action.intelligence, "id": selected_color})
		DeckRules.recolor(action, selected_color)
		remaining_colors[selected_color] -= 1
		if remaining_colors[selected_color] <= 0:
			selected_color = ""
		return ""
	if section == Section.ACTIONS and selected_line >= 0:
		if not DeckRules.can_add_line(action):
			return "half_full"
		DeckRules.add_line(action, to.granted_lines[selected_line])
		history.append({"type": "line", "action": action, "index": selected_line})
		used_lines[selected_line] = true
		selected_line = -1
	return "invalid_selection"


func undo(type: String) -> bool:
	for i in range(history.size() - 1, -1, -1):
		var op: Dictionary = history[i]
		if op["type"] != type:
			continue
		var action: CardAction = op["action"]
		if type == "color":
			action.intelligence = op["prev_intelligence"]
			remaining_colors[op["id"]] += 1
		else:
			DeckRules.remove_last_line(action)
			used_lines[op["index"]] = false
		history.remove_at(i)
		return true
	return false


func pending_colors() -> int:
	return PendingRules.pending_colors(remaining_colors)


func pending_lines() -> int:
	return PendingRules.pending_lines(deck, used_lines)


func can_finish() -> bool:
	return PendingRules.can_finish(remaining_colors, deck, used_lines)
