class_name CombatTurnController
extends RefCounted

const PlanSlotPayloadScript := preload("res://features/combat/scene/plan_slot_payload.gd")

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
var playing: CombatPlayingHalf = null
var starting_line := false
var turn_hand_indices: Array[int] = []
var armed_wild: Wild = Wild.NONE
var keep_half: CombatHalfSelection
var item_half: CombatHalfSelection
var kept_indices: Array[int] = []
var enemy_pending := false
var turn_order: Array[Dictionary] = []

func begin_planning() -> void:
	phase = Phase.PLANNING
	plan_slots = [-1, -1]
	initiative_shift = 0
	turn_cards.clear()
	playing = null
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
	var payload := PlanSlotPayloadScript.parse(data)
	if payload == null:
		return
	match payload.source:
		PlanSlotPayloadScript.HAND:
			if payload.index < visible_hand.size():
				plan_slots[slot] = visible_hand[payload.index]
		PlanSlotPayloadScript.SLOT:
			var from := payload.index
			if from < 0 or from >= plan_slots.size():
				return
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
	playing = null

func clear_action_state() -> void:
	turn_cards.clear()
	playing = null
	keep_half = null
	item_half = null
	armed_wild = Wild.NONE

## Indica si una mitad puede seleccionarse en el estado actual. Los comodines
## no consumen MP; para las cartas normales basta que una línea sea jugable.
func is_half_available(card_index: int, is_top: bool, player_mp: int) -> bool:
	if playing != null and playing.started:
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
func select_half(card_index: int, is_top: bool, player_mp: int, line_cap: int, wild_attack: CardAction, wild_move: CardAction) -> CombatTurnResult:
	if phase != Phase.ACTING or not is_half_available(card_index, is_top, player_mp):
		return CombatTurnResult.make("unavailable")
	match armed_wild:
		Wild.KEEP:
			return CombatTurnResult.make("keep")
		Wild.ITEM:
			return CombatTurnResult.make("item")
	var is_wild := armed_wild != Wild.NONE
	var half: CardAction = wild_attack if armed_wild == Wild.ATTACK else wild_move if armed_wild == Wild.MOVE else turn_cards[card_index].get_action(is_top)
	var lines := CardScaling.resolve_lines(half.enabled_lines(), CardScaling.player_stats())
	if lines.is_empty():
		return CombatTurnResult.make("no_lines")
	playing = CombatPlayingHalf.new()
	playing.card = card_index
	playing.is_top = is_top
	playing.lines = lines
	playing.wild = is_wild
	playing.source = half
	playing.cap = line_cap
	var result := CombatTurnResult.make("playing")
	result.is_wild = is_wild
	return result

## Busca la próxima línea que el jugador pueda pagar y la marca como activa.
## Combat muestra los avisos y entrega la línea a CombatPlayerActions.
func start_current_line(player_mp: int) -> CombatTurnResult:
	if playing == null or phase != Phase.ACTING:
		return CombatTurnResult.make("idle")
	var skipped_for_mp := 0
	var lines: Array = playing.lines
	while playing.index < lines.size() and lines[playing.index].mp_cost > player_mp:
		playing.index += 1
		skipped_for_mp += 1
	if playing.index >= lines.size():
		end_playing()
		var finished := CombatTurnResult.make("finished")
		finished.skipped_for_mp = skipped_for_mp
		return finished
	starting_line = true
	playing.active = true
	var result := CombatTurnResult.make("line")
	result.line = lines[playing.index]
	result.skipped_for_mp = skipped_for_mp
	return result

func finish_starting_line() -> void:
	starting_line = false

func end_playing() -> void:
	playing = null

## Marca la mitad como gastada y devuelve la carta que debe acreditar ecos.
func mark_playing_started() -> CardData:
	if playing == null or playing.started:
		return null
	playing.started = true
	consume_wildcard_half(playing.is_top, playing.card)
	return turn_cards[playing.card] if not playing.wild else null

## Gasta una mitad fuera de la línea en curso (comodines "Mantener"/"Ítem"):
## mismo punto único de escritura que mark_playing_started().
func consume_wildcard_half(is_top: bool, card_index: int) -> void:
	if is_top:
		used_top = card_index
	else:
		used_bottom = card_index

func skip_active_line() -> CombatTurnResult:
	if phase != Phase.ACTING or playing == null or not playing.active:
		return CombatTurnResult.make("idle")
	var result := CombatTurnResult.make("skipped")
	result.skipped = true
	result.echo_card = mark_playing_started()
	return result

## Avanza o termina la mitad según si CombatPlayerActions todavía conserva la
## línea activa. El resultado describe los efectos que debe aplicar Combat.
func resolve_playing(line_still_active: bool, selection_pending: bool) -> CombatTurnResult:
	if playing == null or starting_line or not playing.active:
		return CombatTurnResult.make("idle")
	var line: CardActionLine = playing.lines[playing.index]
	var result := CombatTurnResult.make("pending")
	if not line_still_active:
		result.echo_card = mark_playing_started()
		if playing.counted != playing.index:
			playing.counted = playing.index
			playing.used += 1
			result.mp_cost = line.mp_cost
	if selection_pending:
		return result
	if line_still_active:
		if not playing.started:
			end_playing()
			return CombatTurnResult.make("abandoned")
		result.kind = "line_skipped"
	playing.index += 1
	playing.active = false
	if not line_still_active and playing.used >= playing.cap and playing.index < playing.lines.size():
		result.kind = "cap_reached"
		result.cap = playing.cap
		end_playing()
		return result
	if playing.index >= playing.lines.size():
		end_playing()
		result.kind = "finished"
		return result
	result.kind = "next_line"
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
