extends Node

const HAND_SIZE := 6

const _CombatState = preload("res://features/combat/scene/combat_state.gd")
const _CombatPlayerActions = preload("res://features/combat/scene/combat_player_actions.gd")
const _CombatEnemyAI = preload("res://features/combat/scene/combat_enemy_ai.gd")
const _AiAction   = preload("res://data/enemies/ai_action.gd")
const _AiStrategy = preload("res://data/enemies/ai_strategy.gd")
const _EnemyData  = preload("res://data/enemies/enemy_data.gd")

@onready var player_stats = $UI/MainVBox/TopBar/PlayerStats
@onready var enemy_intent_label = $UI/MainVBox/TopBar/EnemyIntent
@onready var move_mode_button = $UI/MainVBox/TopBar/MoveModeButton
@onready var end_turn_button = $UI/MainVBox/TopBar/EndTurnButton
@onready var message_log = $UI/MainVBox/MiddleRow/SidePanel/MessageLog
@onready var map_area = $CombatWorld/MapArea
@onready var hand_section = $UI/MainVBox/HandArea/HandSection
@onready var draw_pile_button = $UI/MainVBox/HandArea/DrawPileButton
@onready var discard_pile_button = $UI/MainVBox/HandArea/DiscardPileButton
@onready var end_move_button = $UI/MainVBox/HandArea/EndMoveButton
@onready var pile_popup = $UI/PilePopup
@onready var pile_popup_title = $UI/PilePopup/VBox/Header/PopupTitle
@onready var pile_popup_grid = $UI/PilePopup/VBox/CardGrid
@onready var pile_close_button = $UI/PilePopup/VBox/Header/CloseButton
@onready var confirm_popup = $UI/ConfirmPopup
@onready var confirm_label = $UI/ConfirmPopup/VBox/Label
@onready var confirm_yes_button = $UI/ConfirmPopup/VBox/Buttons/YesButton
@onready var confirm_no_button = $UI/ConfirmPopup/VBox/Buttons/NoButton
@onready var confirm_fin_button = $UI/ConfirmPopup/VBox/Buttons/FinButton
@onready var card_preview = $UI/CardPreview

var state
var player_actions
var enemy_ai
var _combat_finished := false
var _preview_card: CardData = null
var _preview_tween: Tween = null

func _ready() -> void:
	GlobalHUD.set_clock_visible(false)
	GlobalHUD.set_clock_paused(true)
	GlobalHUD.set_youns_status_visible(false)
	GlobalHUD.set_debug_stats_visible(false)
	ZoneManager.set_world_visible(false)
	PartyManager.set_party_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LocalizationState.language_changed.connect(_apply_localized_text)
	randomize()
	var cam: Camera3D = $CombatWorld/Camera3D
	cam.look_at_from_position(Vector3(-10.0, 35.0, 78.0), Vector3(30.0, 0.0, 30.0), Vector3.UP)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	$CombatWorld.add_child(we)

	state = _CombatState.new()
	player_actions = _CombatPlayerActions.new()
	player_actions.setup(self, state)

	var enemy_name_str := ""
	var wild_youn: YounData = GameState.pending_wild_youn_data
	if wild_youn:
		GameState.pending_wild_youn_data = null
		state.enemy_hp     = wild_youn.max_hp
		state.enemy_max_hp = wild_youn.max_hp
		map_area.set_enemy_hp(state.enemy_hp)
		map_area.setup_enemy_youn(wild_youn)
		enemy_ai = _CombatEnemyAI.new()
		enemy_ai.setup(self, state, wild_youn.strategy)
		enemy_name_str = wild_youn.youn_name
	else:
		var enemy_data: _EnemyData = GameState.pending_enemy_data
		if enemy_data == null:
			enemy_data = load("res://data/enemies/goblin.tres")
		GameState.pending_enemy_data = null
		state.enemy_hp     = enemy_data.max_hp
		state.enemy_max_hp = enemy_data.max_hp
		map_area.set_enemy_hp(state.enemy_hp)
		map_area.setup_enemy(enemy_data.mesh, enemy_data.mesh_scale, enemy_data.combat_shadow_radius)
		enemy_ai = _CombatEnemyAI.new()
		enemy_ai.setup(self, state, enemy_data.strategy)
		enemy_name_str = LocalizationState.enemy_name(enemy_data.id, enemy_data.enemy_name)

	var _youn = PartyManager.youn
	if is_instance_valid(_youn) and _youn.youn_data:
		map_area.setup_player(_youn.youn_data)

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	move_mode_button.toggled.connect(player_actions._on_move_mode_toggled)
	draw_pile_button.pressed.connect(_on_draw_pile_button_pressed)
	discard_pile_button.pressed.connect(_on_discard_pile_button_pressed)
	pile_close_button.pressed.connect(_on_pile_popup_close)
	confirm_yes_button.pressed.connect(player_actions._on_confirm_yes)
	confirm_no_button.pressed.connect(player_actions._on_confirm_no)
	confirm_fin_button.pressed.connect(player_actions._on_confirm_fin)
	end_move_button.pressed.connect(player_actions._on_end_move_pressed)

	if map_area.has_signal("position_selected"):
		map_area.position_selected.connect(player_actions._on_position_selected)

	hand_section.set_title(LocalizationState.t("combat.hand"))
	hand_section.card_selected.connect(player_actions._on_card_selected)

	setup_draw_pile()
	draw_cards(HAND_SIZE)
	refresh_hand()
	enemy_ai.pick_intent()
	_apply_localized_text()
	update_ui()

	card_preview.hover_enabled = false
	card_preview.set_disabled(true)

	PauseMenu.enabled = true

	log_message(LocalizationState.t("combat.started", [enemy_name_str]))

func _exit_tree() -> void:
	ZoneManager.set_world_visible(true)
	PartyManager.set_party_visible(true)
	GlobalHUD.set_debug_stats_visible(true)

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
			log_message(LocalizationState.t("combat.reshuffle"))
		state.hand.append(state.draw_pile.pop_back())

func discard_hand() -> void:
	state.discard_pile.append_array(state.hand)
	state.hand.clear()

func refresh_hand() -> void:
	hand_section.set_cards(state.hand)
	draw_pile_button.text = LocalizationState.t("combat.draw_pile", [state.draw_pile.size()])
	discard_pile_button.text = LocalizationState.t("combat.discard_pile", [state.discard_pile.size()])
	if _preview_card != null and not state.hand.has(_preview_card):
		hide_card_preview()

# ── Pile popup ────────────────────────────────────────────────────────────────

func _on_draw_pile_button_pressed() -> void:
	var cards: Array[CardData] = []
	cards.assign(state.draw_pile)
	pile_popup_title.text = LocalizationState.t("combat.draw_pile", [cards.size()])
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_discard_pile_button_pressed() -> void:
	var cards: Array[CardData] = []
	cards.assign(state.discard_pile)
	pile_popup_title.text = LocalizationState.t("combat.discard_pile", [cards.size()])
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_pile_popup_close() -> void:
	pile_popup.visible = false

# ── Turn management ───────────────────────────────────────────────────────────

func _on_end_turn_pressed() -> void:
	end_turn_button.disabled = true
	await enemy_ai.take_turn()
	if check_combat_end():
		return
	reset_turn()
	end_turn_button.disabled = false

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
	await _play_player_anim_timed("attack")
	await _play_enemy_anim_timed("damage")

func deal_damage_to_player(amount: int) -> void:
	var dmg: int = max(amount - state.player_block, 0)
	state.player_block = max(state.player_block - amount, 0)
	state.player_hp -= dmg
	await _play_enemy_anim_timed("attack")
	await _play_player_anim_timed("damage")

func _play_player_anim_timed(anim_key: String) -> void:
	map_area.play_player_anim(anim_key)
	await map_area.player_anim_finished
	if not _combat_finished and state.player_hp > 0:
		map_area.play_player_anim("idle")

func _play_enemy_anim_timed(anim_key: String) -> void:
	map_area.play_enemy_anim(anim_key)
	await map_area.enemy_anim_finished
	if not _combat_finished and state.enemy_hp > 0:
		map_area.play_enemy_anim("idle")

# ── UI ────────────────────────────────────────────────────────────────────────

func update_ui() -> void:
	player_stats.text = LocalizationState.t("combat.player_stats", [
		state.player_hp, state.player_block, state.player_energy, state.enemy_hp
	])
	match state.enemy_intent["type"]:
		"attack":
			enemy_intent_label.text = LocalizationState.t("combat.intent.attack", [state.enemy_intent["value"]])
		"range_attack":
			enemy_intent_label.text = LocalizationState.t("combat.intent.range_attack", [state.enemy_intent["value"]])
		"move":
			enemy_intent_label.text = LocalizationState.t("combat.intent.move")
		"retreat":
			enemy_intent_label.text = LocalizationState.t("combat.intent.retreat")
		"block":
			enemy_intent_label.text = LocalizationState.t("combat.intent.block", [state.enemy_intent["value"]])
		"wait":
			enemy_intent_label.text = LocalizationState.t("combat.intent.wait")

func check_combat_end() -> bool:
	if state.enemy_hp <= 0:
		log_message(LocalizationState.t("combat.win"))
		hand_section.disable_cards()
		end_turn_button.disabled = true
		if not _combat_finished:
			_combat_finished = true
			_return_to_world_after_victory.call_deferred()
		return true
	if state.player_hp <= 0:
		log_message(LocalizationState.t("combat.lose"))
		hand_section.disable_cards()
		end_turn_button.disabled = true
		map_area.play_player_anim("die")
		return true
	return false

func show_card_preview(card: CardData) -> void:
	_preview_card = card
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	hand_section.show_all_cards()
	var index: int = state.hand.find(card)
	if index >= 0:
		hand_section.set_card_visible_at(index, false)
	card_preview.set_card(card)
	card_preview.modulate.a = 0.0
	card_preview.visible = true
	_preview_tween = create_tween()
	_preview_tween.tween_property(card_preview, "modulate:a", 1.0, 0.15)

func hide_card_preview() -> void:
	_preview_card = null
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	if not card_preview.visible:
		return
	hand_section.show_all_cards()
	_preview_tween = create_tween()
	_preview_tween.tween_property(card_preview, "modulate:a", 0.0, 0.1)
	_preview_tween.tween_callback(func(): card_preview.visible = false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and card_preview.visible:
		player_actions.cancel_selection()
		get_viewport().set_input_as_handled()

func log_message(text: String) -> void:
	message_log.append_text(text + "\n")

func _return_to_world_after_victory() -> void:
	if not GameState.combat_return_pending:
		return
	GameState.player_save.gold += 300
	GameState.save_player_save()
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://features/world/game_world/game_world.tscn")

func _apply_localized_text(_language: String = "") -> void:
	hand_section.set_title(LocalizationState.t("combat.hand"))
	move_mode_button.text = LocalizationState.t("combat.move")
	end_turn_button.text = LocalizationState.t("combat.end_turn")
	end_move_button.text = LocalizationState.t("combat.end_move")
	confirm_label.text = LocalizationState.t("combat.confirm_action")
	confirm_yes_button.text = LocalizationState.t("combat.yes")
	confirm_no_button.text = LocalizationState.t("combat.no")
	confirm_fin_button.text = LocalizationState.t("combat.finish")
	refresh_hand()
	update_ui()
