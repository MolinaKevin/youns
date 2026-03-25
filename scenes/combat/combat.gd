extends Control

@onready var player_stats = $MainVBox/TopBar/PlayerStats
@onready var enemy_intent_label = $MainVBox/TopBar/EnemyIntent
@onready var end_turn_button = $MainVBox/TopBar/EndTurnButton
@onready var message_log = $MainVBox/BattleArea/SidePanel/MessageLog
@onready var map_area = $MainVBox/BattleArea/MapArea

@onready var hand_sections = $MainVBox/HandSections
@onready var movement_section = $MainVBox/HandSections/MovementSection
@onready var attack_section = $MainVBox/HandSections/AttackSection
@onready var block_section = $MainVBox/HandSections/BlockSection
@onready var ultimate_section = $MainVBox/HandSections/UltimateSection

var player_hp := 40
var player_block := 0
var player_energy := 3
var max_energy := 3

var enemy_hp := 35
var enemy_block := 0
var enemy_intent := {"type": "attack", "value": 7}

var movement_hand: Array = []
var attack_hand: Array = []
var block_hand: Array = []
var ultimate_hand: Array = []

var pending_move_section := ""
var pending_move_index := -1
var pending_move_range := 0

var step_card = preload("res://data/cards/step.tres")
var dash_card = preload("res://data/cards/dash.tres")
var strike_card = preload("res://data/cards/strike.tres")
var slash_card = preload("res://data/cards/slash.tres")
var block_card = preload("res://data/cards/block.tres")
var meteor_card = preload("res://data/cards/meteor.tres")

func _ready() -> void:
	randomize()
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	if map_area.has_signal("tile_selected"):
		map_area.tile_selected.connect(_on_map_tile_selected)

	hand_sections.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_sections.add_theme_constant_override("separation", 24)

	movement_section.custom_minimum_size = Vector2(260, 260)
	attack_section.custom_minimum_size = Vector2(260, 260)
	block_section.custom_minimum_size = Vector2(260, 260)
	ultimate_section.custom_minimum_size = Vector2(260, 260)

	movement_section.set_title("Movement")
	attack_section.set_title("Attack")
	block_section.set_title("Block")
	ultimate_section.set_title("Ultimate")

	movement_section.card_selected.connect(func(card): _on_card_selected("movement", card))
	attack_section.card_selected.connect(func(card): _on_card_selected("attack", card))
	block_section.card_selected.connect(func(card): _on_card_selected("block", card))
	ultimate_section.card_selected.connect(func(card): _on_card_selected("ultimate", card))

	setup_hands()
	refresh_all_hands()
	update_ui()

	movement_section.hide_cards_initially()
	attack_section.hide_cards_initially()
	block_section.hide_cards_initially()
	ultimate_section.hide_cards_initially()

	log_message("Combat started.")

func setup_hands() -> void:
	movement_hand = [step_card, dash_card]
	attack_hand = [strike_card, slash_card]
	block_hand = [block_card, block_card]
	ultimate_hand = [meteor_card]

	print("setup_hands()")
	print("movement_hand size =", movement_hand.size())
	for c in movement_hand:
		print("  movement:", c.name)

	print("attack_hand size =", attack_hand.size())
	for c in attack_hand:
		print("  attack:", c.name)

	print("block_hand size =", block_hand.size())
	for c in block_hand:
		print("  block:", c.name)

	print("ultimate_hand size =", ultimate_hand.size())
	for c in ultimate_hand:
		print("  ultimate:", c.name)


func refresh_all_hands() -> void:
	print("refresh_all_hands()")
	print("  movement ->", movement_hand.size())
	print("  attack   ->", attack_hand.size())
	print("  block    ->", block_hand.size())
	print("  ultimate ->", ultimate_hand.size())

	movement_section.set_cards(movement_hand)
	attack_section.set_cards(attack_hand)
	block_section.set_cards(block_hand)
	ultimate_section.set_cards(ultimate_hand)

func _on_card_selected(section_name: String, card: CardData) -> void:
	var source_hand := get_hand_by_section(section_name)
	var index := source_hand.find(card)

	if index == -1:
		return

	play_card(section_name, index)

func play_card(section_name: String, index: int) -> void:
	var source_hand := get_hand_by_section(section_name)
	if source_hand.is_empty():
		return

	if index < 0 or index >= source_hand.size():
		return

	var card = source_hand[index]

	if card.cost > player_energy:
		log_message("Not enough energy for %s." % card.name)
		return

	match card.card_type:
		"move":
			start_move_selection(section_name, index, card.card_range, card.cost, card.name)
		"melee_attack":
			play_attack_card(section_name, index, card)
		"targeted_attack":
			play_attack_card(section_name, index, card)

func start_move_selection(section_name: String, index: int, move_range: int, energy_cost: int, card_name: String) -> void:
	if energy_cost > player_energy:
		log_message("Not enough energy for %s." % card_name)
		return

	pending_move_section = section_name
	pending_move_index = index
	pending_move_range = move_range

	if map_area.has_method("start_move_selection"):
		map_area.start_move_selection(move_range)

	log_message("Selected %s. Choose a tile up to %d spaces away." % [card_name, move_range])

func play_attack_card(section_name: String, index: int, card: CardData) -> void:
	if not map_area.has_method("is_enemy_in_melee_range"):
		log_message("MapArea is missing melee logic.")
		return

	if not map_area.is_enemy_in_melee_range():
		log_message("%s failed. Enemy is not in melee range." % card.name)
		return

	player_energy -= card.cost
	deal_damage_to_enemy(card.damage)
	log_message("Played %s for %d damage." % [card.name, card.damage])

	var source_hand = get_hand_by_section(section_name)
	source_hand.remove_at(index)

	refresh_all_hands()
	update_ui()
	check_combat_end()

func get_hand_by_section(section_name: String) -> Array:
	match section_name:
		"movement":
			return movement_hand
		"attack":
			return attack_hand
		"block":
			return block_hand
		"ultimate":
			return ultimate_hand
		_:
			return []

func _on_map_tile_selected(cell: Vector2i) -> void:
	if pending_move_index < 0:
		return

	if not map_area.has_method("try_move_player_to"):
		return

	var moved: bool = map_area.try_move_player_to(cell, pending_move_range)
	if not moved:
		log_message("Invalid move.")
		return

	var source_hand = get_hand_by_section(pending_move_section)
	if pending_move_index >= 0 and pending_move_index < source_hand.size():
		var card = source_hand[pending_move_index]
		player_energy -= card.cost
		log_message("Played %s and moved." % card.name)
		source_hand.remove_at(pending_move_index)

	clear_pending_move()
	refresh_all_hands()
	update_ui()

func clear_pending_move() -> void:
	pending_move_section = ""
	pending_move_index = -1
	pending_move_range = 0

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

	enemy_intent_label.text = "Intent: %s %d" % [
		enemy_intent["type"].capitalize(),
		enemy_intent["value"]
	]

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
	movement_section.disable_cards()
	attack_section.disable_cards()
	block_section.disable_cards()
	ultimate_section.disable_cards()

func enemy_take_turn() -> void:
	deal_damage_to_player(enemy_intent["value"])
	log_message("Enemy attacks for %d." % enemy_intent["value"])
	update_ui()

func reset_turn() -> void:
	player_energy = max_energy
	player_block = 0
	clear_pending_move()
	setup_hands()
	refresh_all_hands()
	update_ui()

func log_message(text: String) -> void:
	message_log.append_text(text + "\n")

func _on_end_turn_pressed() -> void:
	enemy_take_turn()
	if check_combat_end():
		return
	reset_turn()
