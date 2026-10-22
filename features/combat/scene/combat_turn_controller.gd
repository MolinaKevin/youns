class_name CombatTurnController
extends RefCounted

## Estado y transiciones puras de una ronda. La escena Combat conserva la UI,
## las corutinas y la ejecución de acciones, pero este controlador es dueño de
## la planificación, las mitades elegidas y el orden de iniciativa.
enum Phase { PLANNING, REVEAL, ENEMY, ACTING }
enum Wild { NONE, ATTACK, MOVE, KEEP, ITEM }

var phase: Phase = Phase.PLANNING
var plan_slots: Array[int] = [-1, -1]
var initiative_shift := 0
var hand_view_indices: Array[int] = []
var turn_cards: Array[CardData] = []
var used_top := -1
var used_bottom := -1
var playing: Dictionary = {}
var starting_line := false
var turn_hand_indices: Array[int] = []
var armed_wild: Wild = Wild.NONE
var keep_half: Dictionary = {}
var item_half: Dictionary = {}
var kept_indices: Array[int] = []
var enemy_pending := false
var turn_order: Array[Dictionary] = []

func begin_planning() -> void:
	phase = Phase.PLANNING
	plan_slots = [-1, -1]
	initiative_shift = 0
	turn_cards.clear()
	playing = {}
	armed_wild = Wild.NONE

func try_plan_card(hand_index: int) -> bool:
	var free_slot := plan_slots.find(-1)
	if free_slot < 0:
		return false
	plan_slots[free_slot] = hand_index
	return true

func clear_plan_slot(slot: int) -> void:
	plan_slots[slot] = -1

func drop_plan_slot(slot: int, data: Dictionary, visible_hand: Array[int]) -> void:
	match data.get("source"):
		"hand":
			plan_slots[slot] = visible_hand[data["index"]]
		"slot":
			var from: int = data["index"]
			var moved := plan_slots[from]
			plan_slots[from] = plan_slots[slot]
			plan_slots[slot] = moved

func adjust_initiative(delta: int, max_shift: int) -> void:
	initiative_shift = clampi(initiative_shift + delta, -max_shift, max_shift)

func player_initiative(lead: CardData) -> int:
	return maxi(1, lead.initiative + initiative_shift)

func commit_plan(hand: Array[CardData], lead_index: int, second_index: int) -> void:
	turn_cards.assign([hand[lead_index], hand[second_index]])
	turn_hand_indices.assign([lead_index, second_index])
	used_top = -1
	used_bottom = -1
	playing = {}

func clear_action_state() -> void:
	turn_cards.clear()
	playing = {}
	keep_half = {}
	item_half = {}
	armed_wild = Wild.NONE

## Indica si una mitad puede seleccionarse en el estado actual. Los comodines
## no consumen MP; para las cartas normales basta que una línea sea jugable.
func is_half_available(card_index: int, is_top: bool, player_mp: int) -> bool:
	if not playing.is_empty() and playing["started"]:
		return false
	if card_index == used_top or card_index == used_bottom:
		return false
	if (used_top if is_top else used_bottom) != -1:
		return false
	match armed_wild:
		Wild.ATTACK:
			return is_top
		Wild.MOVE:
			return not is_top
		Wild.KEEP, Wild.ITEM:
			return true
	var half: CardAction = turn_cards[card_index].get_action(is_top)
	return half.enabled_lines().any(func(line: CardActionLine) -> bool: return line.mp_cost <= player_mp)

## Prepara una mitad para jugar. Combat resuelve las dos variantes que abren UI
## (keep/item), y ejecuta la línea devuelta en el mapa.
func select_half(card_index: int, is_top: bool, player_mp: int, line_cap: int, wild_attack: CardAction, wild_move: CardAction) -> Dictionary:
	if phase != Phase.ACTING or not is_half_available(card_index, is_top, player_mp):
		return {"kind": "unavailable"}
	match armed_wild:
		Wild.KEEP:
			return {"kind": "keep"}
		Wild.ITEM:
			return {"kind": "item"}
	var is_wild := armed_wild != Wild.NONE
	var half: CardAction = wild_attack if armed_wild == Wild.ATTACK else wild_move if armed_wild == Wild.MOVE else turn_cards[card_index].get_action(is_top)
	var lines := CardScaling.resolve_lines(half.enabled_lines(), CardScaling.player_stats())
	if lines.is_empty():
		return {"kind": "no_lines"}
	playing = {
		"card": card_index, "is_top": is_top, "lines": lines, "index": 0,
		"started": false, "active": false, "wild": is_wild, "source": half,
		"used": 0, "cap": line_cap,
	}
	return {"kind": "playing", "is_wild": is_wild}

## Busca la próxima línea que el jugador pueda pagar y la marca como activa.
## Combat muestra los avisos y entrega la línea a CombatPlayerActions.
func start_current_line(player_mp: int) -> Dictionary:
	if playing.is_empty() or phase != Phase.ACTING:
		return {"kind": "idle"}
	var skipped_for_mp := 0
	var lines: Array = playing["lines"]
	while playing["index"] < lines.size() and lines[playing["index"]].mp_cost > player_mp:
		playing["index"] += 1
		skipped_for_mp += 1
	if playing["index"] >= lines.size():
		end_playing()
		return {"kind": "finished", "skipped_for_mp": skipped_for_mp}
	starting_line = true
	playing["active"] = true
	return {"kind": "line", "line": lines[playing["index"]], "skipped_for_mp": skipped_for_mp}

func finish_starting_line() -> void:
	starting_line = false

func end_playing() -> void:
	playing = {}

## Marca la mitad como gastada y devuelve la carta que debe acreditar ecos.
func mark_playing_started() -> Dictionary:
	if playing.is_empty() or playing["started"]:
		return {}
	playing["started"] = true
	if playing["is_top"]:
		used_top = playing["card"]
	else:
		used_bottom = playing["card"]
	return {"echo_card": turn_cards[playing["card"]] if not playing["wild"] else null}

func skip_active_line() -> Dictionary:
	if phase != Phase.ACTING or playing.is_empty() or not playing["active"]:
		return {"skipped": false}
	var started := mark_playing_started()
	return {"skipped": true, "echo_card": started.get("echo_card")}

## Avanza o termina la mitad según si CombatPlayerActions todavía conserva la
## línea activa. El resultado describe los efectos que debe aplicar Combat.
func resolve_playing(line_still_active: bool, selection_pending: bool) -> Dictionary:
	if playing.is_empty() or starting_line or not playing["active"]:
		return {"kind": "idle"}
	var line: CardActionLine = playing["lines"][playing["index"]]
	var result := {"kind": "pending", "mp_cost": 0, "echo_card": null, "cap": -1}
	if not line_still_active:
		var started := mark_playing_started()
		result["echo_card"] = started.get("echo_card")
		if playing.get("counted", -1) != playing["index"]:
			playing["counted"] = playing["index"]
			playing["used"] += 1
			result["mp_cost"] = line.mp_cost
	if selection_pending:
		return result
	if line_still_active:
		if not playing["started"]:
			end_playing()
			return {"kind": "abandoned"}
		result["kind"] = "line_skipped"
	playing["index"] += 1
	playing["active"] = false
	if not line_still_active and playing["used"] >= playing["cap"] and playing["index"] < playing["lines"].size():
		result["kind"] = "cap_reached"
		result["cap"] = playing["cap"]
		end_playing()
		return result
	if playing["index"] >= playing["lines"].size():
		end_playing()
		result["kind"] = "finished"
		return result
	result["kind"] = "next_line"
	return result

func build_turn_order(player_name: String, p_player_initiative: int, enemy_name: String, enemy_initiative: int) -> void:
	turn_order.assign([
		{"name": player_name, "initiative": p_player_initiative, "is_player": true},
		{"name": enemy_name, "initiative": enemy_initiative, "is_player": false},
	])
	turn_order.sort_custom(func(a, b):
		if a["initiative"] != b["initiative"]:
			return a["initiative"] < b["initiative"]
		return a["is_player"] and not b["is_player"])
