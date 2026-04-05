extends Control

const MOVE_MODE_RANGE := 10

@onready var player_stats = $MainVBox/TopBar/PlayerStats
@onready var enemy_intent_label = $MainVBox/TopBar/EnemyIntent
@onready var move_mode_button = $MainVBox/TopBar/MoveModeButton
@onready var end_turn_button = $MainVBox/TopBar/EndTurnButton
@onready var message_log = $MainVBox/BattleArea/SidePanel/MessageLog
@onready var map_area = $MainVBox/BattleArea/MapArea
@onready var hand_section = $MainVBox/HandArea/HandSection
@onready var draw_pile_button = $MainVBox/HandArea/DrawPileButton
@onready var discard_pile_button = $MainVBox/HandArea/DiscardPileButton
@onready var pile_popup = $PilePopup
@onready var pile_popup_title = $PilePopup/VBox/Header/PopupTitle
@onready var pile_popup_grid = $PilePopup/VBox/CardGrid
@onready var pile_close_button = $PilePopup/VBox/Header/CloseButton
@onready var confirm_popup = $ConfirmPopup
@onready var confirm_yes_button = $ConfirmPopup/VBox/Buttons/YesButton
@onready var confirm_no_button = $ConfirmPopup/VBox/Buttons/NoButton
@onready var confirm_fin_button = $ConfirmPopup/VBox/Buttons/FinButton
@onready var end_move_button = $MainVBox/HandArea/EndMoveButton

const HAND_SIZE := 6

var player_hp := 40
var player_block := 0
var player_energy := 3
var max_energy := 3

var enemy_hp := 35
var enemy_block := 0
var enemy_intent := {"type": "attack", "value": 7}

const ENEMY_MOVE_RANGE := 20
const ENEMY_MELEE_RANGE := 2
const ENEMY_MELEE_DAMAGE := 7

var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []

var move_mode := false

var pending_move_section := ""
var pending_move_index := -1
var pending_move_range := 0
var pending_move_started := false

var pending_attack_section := ""
var pending_attack_index := -1
var pending_attack_range := 0

var pending_grenade_index := -1
var pending_trap_index := -1

var pending_cell := Vector2i(-1, -1)

func _ready() -> void:
	randomize()
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	move_mode_button.toggled.connect(_on_move_mode_toggled)
	draw_pile_button.pressed.connect(_on_draw_pile_button_pressed)
	discard_pile_button.pressed.connect(_on_discard_pile_button_pressed)
	pile_close_button.pressed.connect(_on_pile_popup_close)
	confirm_yes_button.pressed.connect(_on_confirm_yes)
	confirm_no_button.pressed.connect(_on_confirm_no)
	confirm_fin_button.pressed.connect(_on_confirm_fin)
	end_move_button.pressed.connect(_on_end_move_pressed)

	if map_area.has_signal("tile_selected"):
		map_area.tile_selected.connect(_on_map_tile_selected)

	hand_section.set_title("Mano")
	hand_section.card_selected.connect(_on_card_selected)

	setup_draw_pile()
	draw_cards(HAND_SIZE)
	refresh_hand()
	_pick_enemy_intent()
	update_ui()

	log_message("Combat started.")

func setup_draw_pile() -> void:
	var deck_cards := CardDatabase.get_cards_from_ids(GameState.player_save.equipped_deck_ids)
	draw_pile.assign(deck_cards)
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()

func draw_cards(n: int) -> void:
	for i in n:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.assign(discard_pile)
			draw_pile.shuffle()
			discard_pile.clear()
			log_message("Mazo vacío — se mezcló el descarte.")
		hand.append(draw_pile.pop_back())

func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()

func refresh_hand() -> void:
	hand_section.set_cards(hand)
	_refresh_draw_pile_display()

func _refresh_draw_pile_display() -> void:
	draw_pile_button.text = "Mazo (%d)" % draw_pile.size()
	discard_pile_button.text = "Descarte (%d)" % discard_pile.size()

func _on_draw_pile_button_pressed() -> void:
	var cards: Array[CardData] = []
	cards.assign(draw_pile)
	pile_popup_title.text = "Mazo (%d)" % cards.size()
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_discard_pile_button_pressed() -> void:
	var cards: Array[CardData] = []
	cards.assign(discard_pile)
	pile_popup_title.text = "Descarte (%d)" % cards.size()
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_pile_popup_close() -> void:
	pile_popup.visible = false

func _on_move_mode_toggled(pressed: bool) -> void:
	move_mode = pressed
	if not pressed:
		clear_pending_move()

func _on_card_selected(card: CardData) -> void:
	var index := hand.find(card)
	if index == -1:
		return

	if move_mode:
		play_as_move(index)
	else:
		play_card(index)

func play_as_move(index: int) -> void:
	var card = hand[index]
	if card.cost > player_energy:
		log_message("Not enough energy.")
		return
	pending_move_section = "hand"
	pending_move_index = index
	pending_move_range = MOVE_MODE_RANGE
	map_area.start_move_selection(MOVE_MODE_RANGE)
	log_message("Move mode: choose a tile up to %d spaces away." % MOVE_MODE_RANGE)

func play_card(index: int) -> void:
	var card = hand[index]
	if card.cost > player_energy:
		log_message("Not enough energy for %s." % card.name)
		return

	match card.card_type:
		"move":
			start_move_selection("hand", index, card.card_range, card.cost, card.name)
		"melee_attack":
			play_attack_card(index, card, true)
		"range_attack":
			start_range_attack_selection(index, card)
		"targeted_attack":
			play_attack_card(index, card, false)
		"grenade":
			start_grenade_selection(index, card)
		"trap_place":
			start_trap_selection(index, card, true)
		"trap_throw":
			start_trap_selection(index, card, false)
		"block":
			player_block += card.block_amount
			player_energy -= card.cost
			log_message("Played %s. Block: %d" % [card.name, player_block])
			discard_pile.append(hand[index])
			hand.remove_at(index)
			refresh_hand()
			update_ui()

func start_trap_selection(index: int, card: CardData, nearby: bool) -> void:
	if card.cost > player_energy:
		log_message("Not enough energy for %s." % card.name)
		return
	pending_trap_index = index
	if nearby:
		map_area.start_trap_placement(8)
		log_message("Place %s nearby (range 8)." % card.name)
	else:
		map_area.start_trap_placement(card.throw_range)
		log_message("Throw %s — choose a tile up to %d spaces away." % [card.name, card.throw_range])

func start_grenade_selection(index: int, card: CardData) -> void:
	if card.cost > player_energy:
		log_message("Not enough energy for %s." % card.name)
		return
	pending_grenade_index = index
	map_area.start_trap_placement(card.throw_range)
	log_message("Selected %s. Choose a tile up to %d spaces away (bounce: %.1f)." % [card.name, card.throw_range, card.bounce])

func start_range_attack_selection(index: int, card: CardData) -> void:
	pending_attack_section = "hand"
	pending_attack_index = index
	pending_attack_range = card.card_range
	map_area.start_attack_selection(card.card_range)
	log_message("Selected %s. Click to confirm attack (range: %d)." % [card.name, card.card_range])

func start_move_selection(section_name: String, index: int, move_range: int, energy_cost: int, card_name: String) -> void:
	if energy_cost > player_energy:
		log_message("Not enough energy for %s." % card_name)
		return
	pending_move_section = section_name
	pending_move_index = index
	pending_move_range = move_range
	map_area.start_move_selection(move_range)
	log_message("Selected %s. Choose a tile up to %d spaces away." % [card_name, move_range])

func play_attack_card(index: int, card: CardData, requires_melee: bool) -> void:
	if requires_melee:
		if not map_area.has_method("is_enemy_in_melee_range"):
			log_message("MapArea is missing melee logic.")
			return
		if not map_area.is_enemy_in_melee_range():
			log_message("%s failed. Enemy is not in melee range." % card.name)
			return

	player_energy -= card.cost
	deal_damage_to_enemy(card.damage)
	log_message("Played %s for %d damage." % [card.name, card.damage])
	discard_pile.append(hand[index])
	hand.remove_at(index)
	refresh_hand()
	update_ui()
	check_combat_end()

func _on_map_tile_selected(cell: Vector2i) -> void:
	var has_pending := (
		pending_trap_index >= 0 or
		pending_grenade_index >= 0 or
		pending_attack_index >= 0 or
		pending_move_index >= 0 or
		pending_move_started
	)
	if not has_pending:
		return

	pending_cell = cell
	if (pending_move_index >= 0 or pending_move_started) and map_area.has_method("show_move_preview"):
		map_area.show_move_preview(cell)
	confirm_fin_button.visible = pending_move_started
	confirm_popup.visible = true

func _on_confirm_yes() -> void:
	confirm_popup.visible = false
	var cell := pending_cell
	pending_cell = Vector2i(-1, -1)
	_execute_tile_action(cell)
	if map_area.has_method("clear_move_preview"):
		map_area.clear_move_preview()

func _on_confirm_no() -> void:
	confirm_popup.visible = false
	if map_area.has_method("clear_move_preview"):
		map_area.clear_move_preview()
	pending_cell = Vector2i(-1, -1)

func _on_confirm_fin() -> void:
	confirm_popup.visible = false
	if map_area.has_method("clear_move_preview"):
		map_area.clear_move_preview()
	pending_cell = Vector2i(-1, -1)
	_finish_movement()

func _on_end_move_pressed() -> void:
	_finish_movement()

func _finish_movement() -> void:
	end_move_button.visible = false
	clear_pending_move()
	if move_mode:
		move_mode_button.button_pressed = false
	refresh_hand()
	update_ui()

func _execute_tile_action(cell: Vector2i) -> void:
	if pending_trap_index >= 0:
		_place_trap(cell)
		return

	if pending_grenade_index >= 0:
		_throw_grenade(cell)
		return

	if pending_attack_index >= 0:
		_confirm_range_attack()
		return

	if pending_move_index < 0 and not pending_move_started:
		return

	if not map_area.has_method("try_move_player_to"):
		return

	var dist_moved: float = map_area.get_path_cost(cell)
	var path: Array[Vector2i] = map_area.move_preview_path.duplicate()
	var moved: bool = map_area.try_move_player_to(cell, pending_move_range)
	if not moved:
		log_message("Invalid move.")
		return

	var trap_dmg: int = map_area.check_and_trigger_traps_along_path(path, map_area.player_shape)
	if trap_dmg > 0:
		deal_damage_to_player(trap_dmg)
		log_message("Pisaste una trampa en el camino! %d daño." % trap_dmg)
		if check_combat_end():
			return

	if not pending_move_started:
		var card = hand[pending_move_index]
		player_energy -= card.cost
		log_message("Played %s." % card.name)
		discard_pile.append(hand[pending_move_index])
		hand.remove_at(pending_move_index)
		pending_move_index = -1
		pending_move_started = true

	var remaining := maxi(0, pending_move_range - roundi(dist_moved))
	if remaining > 0:
		log_message("Rango restante: %d" % remaining)
		pending_move_range = remaining
		map_area.start_move_selection(remaining)
		end_move_button.visible = true
		refresh_hand()
		update_ui()
	else:
		end_move_button.visible = false
		clear_pending_move()
		if move_mode:
			move_mode_button.button_pressed = false
		refresh_hand()
		update_ui()

func _place_trap(cell: Vector2i) -> void:
	var card: CardData = hand[pending_trap_index]
	var is_nearby := card.card_type == "trap_place"

	if is_nearby and map_area.movement_distance(map_area.player_pos, cell) > 8.0:
		log_message("Too far to place %s." % card.name)
		return

	if not is_nearby and card.throw_range > 0 and map_area.movement_distance(map_area.player_pos, cell) > float(card.throw_range):
		log_message("Too far to throw %s." % card.name)
		return

	player_energy -= card.cost
	map_area.place_trap(cell, card.card_range, card.damage, card.name)
	log_message("Placed %s at (%d,%d)." % [card.name, cell.x, cell.y])

	discard_pile.append(hand[pending_trap_index])
	hand.remove_at(pending_trap_index)
	pending_trap_index = -1
	map_area.clear_trap_placement()
	refresh_hand()
	update_ui()

func _throw_grenade(target: Vector2i) -> void:
	var card: CardData = hand[pending_grenade_index]

	if card.throw_range > 0 and map_area.movement_distance(map_area.player_pos, target) > float(card.throw_range):
		log_message("Too far to throw %s." % card.name)
		return

	map_area.clear_trap_placement()
	var landing: Vector2i = map_area.calculate_grenade_landing(map_area.player_pos, target, card.bounce)

	map_area.show_grenade_preview(landing, card.card_range)

	if map_area.is_enemy_in_explosion(landing, card.card_range):
		player_energy -= card.cost
		deal_damage_to_enemy(card.damage)
		log_message("%s lands at (%d,%d) — %d damage!" % [card.name, landing.x, landing.y, card.damage])
	else:
		player_energy -= card.cost
		log_message("%s lands at (%d,%d) — miss!" % [card.name, landing.x, landing.y])

	discard_pile.append(hand[pending_grenade_index])
	hand.remove_at(pending_grenade_index)
	pending_grenade_index = -1

	await get_tree().create_timer(0.6).timeout
	map_area.clear_grenade_preview()

	refresh_hand()
	update_ui()
	check_combat_end()

func _confirm_range_attack() -> void:
	if pending_attack_index < 0 or pending_attack_index >= hand.size():
		clear_pending_attack()
		return

	var card = hand[pending_attack_index]

	if not map_area.is_enemy_in_attack_range(pending_attack_range):
		log_message("%s missed. Enemy out of range." % card.name)
		clear_pending_attack()
		return

	player_energy -= card.cost
	deal_damage_to_enemy(card.damage)
	log_message("Played %s for %d damage." % [card.name, card.damage])
	discard_pile.append(hand[pending_attack_index])
	hand.remove_at(pending_attack_index)

	clear_pending_attack()
	refresh_hand()
	update_ui()
	check_combat_end()

func clear_pending_attack() -> void:
	pending_attack_section = ""
	pending_attack_index = -1
	pending_attack_range = 0
	map_area.clear_attack_selection()

func clear_pending_move() -> void:
	pending_move_section = ""
	pending_move_index = -1
	pending_move_range = 0
	pending_move_started = false
	end_move_button.visible = false
	if map_area.has_method("clear_move_selection"):
		map_area.clear_move_selection()

func deal_damage_to_enemy(amount: int) -> void:
	var damage_after_block = max(amount - enemy_block, 0)
	enemy_block = max(enemy_block - amount, 0)
	enemy_hp -= damage_after_block
	if map_area.has_method("set_enemy_hp"):
		map_area.set_enemy_hp(enemy_hp)

func deal_damage_to_player(amount: int) -> void:
	var damage_after_block = max(amount - player_block, 0)
	player_block = max(player_block - amount, 0)
	player_hp -= damage_after_block

func update_ui() -> void:
	player_stats.text = "HP: %d | Block: %d | Energy: %d | Enemy HP: %d" % [
		player_hp, player_block, player_energy, enemy_hp
	]
	match enemy_intent["type"]:
		"attack":
			enemy_intent_label.text = "Intent: Attack %d" % enemy_intent["value"]
		"move":
			enemy_intent_label.text = "Intent: Move"

func check_combat_end() -> bool:
	if enemy_hp <= 0:
		log_message("You win.")
		disable_all_cards()
		end_turn_button.disabled = true
		return true
	if player_hp <= 0:
		log_message("You lose.")
		disable_all_cards()
		end_turn_button.disabled = true
		return true
	return false

func disable_all_cards() -> void:
	hand_section.disable_cards()

func _pick_enemy_intent() -> void:
	var dist: float = map_area.movement_distance(map_area.enemy_pos, map_area.player_pos)
	var roll := randi() % 100
	if dist <= float(ENEMY_MELEE_RANGE):
		enemy_intent = {"type": "attack", "value": ENEMY_MELEE_DAMAGE}
	elif dist <= 12.0:
		if roll < 65:
			enemy_intent = {"type": "attack", "value": ENEMY_MELEE_DAMAGE}
		else:
			enemy_intent = {"type": "move", "value": ENEMY_MOVE_RANGE}
	else:
		if roll < 25:
			enemy_intent = {"type": "attack", "value": ENEMY_MELEE_DAMAGE}
		else:
			enemy_intent = {"type": "move", "value": ENEMY_MOVE_RANGE}

func enemy_take_turn() -> void:
	var trap_dmg: int = map_area.check_and_trigger_traps(map_area.enemy_pos, map_area.enemy_shape)
	if trap_dmg > 0:
		deal_damage_to_enemy(trap_dmg)
		log_message("Enemy triggered a trap! %d damage." % trap_dmg)
		if check_combat_end():
			return

	match enemy_intent["type"]:
		"attack":
			if map_area.is_player_in_melee_range():
				deal_damage_to_player(enemy_intent["value"])
				log_message("Enemy attacks for %d." % enemy_intent["value"])
			else:
				map_area.move_enemy_toward(map_area.player_pos, ENEMY_MOVE_RANGE)
				log_message("Enemy wanted to attack but moved closer instead.")
		"move":
			var moved: bool = map_area.move_enemy_toward(map_area.player_pos, ENEMY_MOVE_RANGE)
			if moved:
				log_message("Enemy moves toward you.")
			else:
				log_message("Enemy couldn't move.")

	update_ui()
	_pick_enemy_intent()

func reset_turn() -> void:
	player_energy = max_energy
	player_block = 0
	clear_pending_move()
	clear_pending_attack()
	pending_grenade_index = -1
	map_area.clear_grenade_preview()
	pending_trap_index = -1
	map_area.clear_trap_placement()
	move_mode_button.button_pressed = false
	discard_hand()
	draw_cards(HAND_SIZE)
	refresh_hand()
	update_ui()

func log_message(text: String) -> void:
	message_log.append_text(text + "\n")

func _on_end_turn_pressed() -> void:
	enemy_take_turn()
	if check_combat_end():
		return
	reset_turn()
