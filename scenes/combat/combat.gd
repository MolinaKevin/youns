extends Control

const HAND_SIZE := 6

const _CombatState = preload("res://scenes/combat/combat_state.gd")
const _CombatPlayerActions = preload("res://scenes/combat/combat_player_actions.gd")
const _CombatEnemyAI = preload("res://scenes/combat/combat_enemy_ai.gd")

@onready var player_stats = $MainVBox/TopBar/PlayerStats
@onready var enemy_intent_label = $MainVBox/TopBar/EnemyIntent
@onready var move_mode_button = $MainVBox/TopBar/MoveModeButton
@onready var end_turn_button = $MainVBox/TopBar/EndTurnButton
@onready var message_log = $MainVBox/BattleArea/SidePanel/MessageLog
@onready var map_area = $MainVBox/BattleArea/MapArea
@onready var hand_section = $MainVBox/HandArea/HandSection
@onready var draw_pile_button = $MainVBox/HandArea/DrawPileButton
@onready var discard_pile_button = $MainVBox/HandArea/DiscardPileButton
@onready var end_move_button = $MainVBox/HandArea/EndMoveButton
@onready var pile_popup = $PilePopup
@onready var pile_popup_title = $PilePopup/VBox/Header/PopupTitle
@onready var pile_popup_grid = $PilePopup/VBox/CardGrid
@onready var pile_close_button = $PilePopup/VBox/Header/CloseButton
@onready var confirm_popup = $ConfirmPopup
@onready var confirm_yes_button = $ConfirmPopup/VBox/Buttons/YesButton
@onready var confirm_no_button = $ConfirmPopup/VBox/Buttons/NoButton
@onready var confirm_fin_button = $ConfirmPopup/VBox/Buttons/FinButton

var state
var player_actions
var enemy_ai

func _ready() -> void:
	randomize()
	state = _CombatState.new()
	player_actions = _CombatPlayerActions.new()
	player_actions.setup(self, state)
	enemy_ai = _CombatEnemyAI.new()
	enemy_ai.setup(self, state)

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	move_mode_button.toggled.connect(player_actions._on_move_mode_toggled)
	draw_pile_button.pressed.connect(_on_draw_pile_button_pressed)
	discard_pile_button.pressed.connect(_on_discard_pile_button_pressed)
	pile_close_button.pressed.connect(_on_pile_popup_close)
	confirm_yes_button.pressed.connect(player_actions._on_confirm_yes)
	confirm_no_button.pressed.connect(player_actions._on_confirm_no)
	confirm_fin_button.pressed.connect(player_actions._on_confirm_fin)
	end_move_button.pressed.connect(player_actions._on_end_move_pressed)

	if map_area.has_signal("tile_selected"):
		map_area.tile_selected.connect(player_actions._on_map_tile_selected)

	hand_section.set_title("Mano")
	hand_section.card_selected.connect(player_actions._on_card_selected)

	setup_draw_pile()
	draw_cards(HAND_SIZE)
	refresh_hand()
	enemy_ai.pick_intent()
	update_ui()

	PauseMenu.enabled = true

	log_message("Combat started.")

# ── Card pile management ──────────────────────────────────────────────────────

func setup_draw_pile() -> void:
	var deck_cards := CardDatabase.get_cards_from_ids(GameState.player_save.equipped_deck_ids)
	state.draw_pile.assign(deck_cards)
	state.draw_pile.shuffle()
	state.discard_pile.clear()
	state.hand.clear()

func draw_cards(n: int) -> void:
	for i in n:
		if state.draw_pile.is_empty():
			if state.discard_pile.is_empty():
				break
			state.draw_pile.assign(state.discard_pile)
			state.draw_pile.shuffle()
			state.discard_pile.clear()
			log_message("Mazo vacío — se mezcló el descarte.")
		state.hand.append(state.draw_pile.pop_back())

func discard_hand() -> void:
	state.discard_pile.append_array(state.hand)
	state.hand.clear()

func refresh_hand() -> void:
	hand_section.set_cards(state.hand)
	draw_pile_button.text = "Mazo (%d)" % state.draw_pile.size()
	discard_pile_button.text = "Descarte (%d)" % state.discard_pile.size()

# ── Pile popup ────────────────────────────────────────────────────────────────

func _on_draw_pile_button_pressed() -> void:
	var cards: Array[CardData] = []
	cards.assign(state.draw_pile)
	pile_popup_title.text = "Mazo (%d)" % cards.size()
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_discard_pile_button_pressed() -> void:
	var cards: Array[CardData] = []
	cards.assign(state.discard_pile)
	pile_popup_title.text = "Descarte (%d)" % cards.size()
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_pile_popup_close() -> void:
	pile_popup.visible = false

# ── Turn management ───────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	enemy_ai.take_turn()
	if check_combat_end():
		return
	reset_turn()

func reset_turn() -> void:
	state.player_energy = state.max_energy
	state.player_block = 0
	player_actions.reset()
	discard_hand()
	draw_cards(HAND_SIZE)
	refresh_hand()
	update_ui()

# ── Damage ────────────────────────────────────────────────────────────────────

func deal_damage_to_enemy(amount: int) -> void:
	var dmg: int = max(amount - state.enemy_block, 0)
	state.enemy_block = max(state.enemy_block - amount, 0)
	state.enemy_hp -= dmg
	if map_area.has_method("set_enemy_hp"):
		map_area.set_enemy_hp(state.enemy_hp)

func deal_damage_to_player(amount: int) -> void:
	var dmg: int = max(amount - state.player_block, 0)
	state.player_block = max(state.player_block - amount, 0)
	state.player_hp -= dmg

# ── UI ────────────────────────────────────────────────────────────────────────

func update_ui() -> void:
	player_stats.text = "HP: %d | Block: %d | Energy: %d | Enemy HP: %d" % [
		state.player_hp, state.player_block, state.player_energy, state.enemy_hp
	]
	match state.enemy_intent["type"]:
		"attack":
			enemy_intent_label.text = "Intent: Attack %d" % state.enemy_intent["value"]
		"move":
			enemy_intent_label.text = "Intent: Move"

func check_combat_end() -> bool:
	if state.enemy_hp <= 0:
		log_message("You win.")
		hand_section.disable_cards()
		end_turn_button.disabled = true
		return true
	if state.player_hp <= 0:
		log_message("You lose.")
		hand_section.disable_cards()
		end_turn_button.disabled = true
		return true
	return false

func log_message(text: String) -> void:
	message_log.append_text(text + "\n")
