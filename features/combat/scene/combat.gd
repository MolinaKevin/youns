class_name Combat
extends Node

const HAND_SIZE := 6
const DEFAULT_ENEMY_INITIATIVE := 50
## Oro que da ganar un combate (se suma al volver al mundo).
const VICTORY_GOLD := 300
## Estadísticas que suma ganar un combate en el mundo: +1 a cada una (8 en total).
## A propósito rinde menos que una hora de entrenamiento (+10), pero no gasta tiempo.
## Provisorio: las recompensas por combate se van a acomodar (docs/TODO.md).
const VICTORY_STAT_GAINS := {
	"constitucion": 1, "mente": 1, "fuerza": 1, "resistencia": 1,
	"agilidad": 1, "tecnica": 1, "inteligencia": 1, "espiritu": 1,
}
## Segundos entre la muerte (del enemigo o del jugador) y la pantalla de fin de lucha.
const VICTORY_SCREEN_DELAY := 0.8
## Tamaño de la carta del enemigo mientras se revela en el centro.
const REVEAL_CARD_ZOOM := 1.5
## Tamaño de las cartas dadas vuelta (las que el enemigo no eligió) respecto de la elegida.
const CARD_BACK_SCALE := 0.8
## Distancia entre los lugares de la fila, en anchos de la carta elegida (<1:
## se superponen un poco para que entren las 3).
const CARD_SLOT_SPACING := 0.8
## Segundos que se ve el orden de la ronda antes de que actúe el enemigo.
const TURN_ORDER_PAUSE := 0.8

const WILD_ATTACK: CardAction = preload("res://data/wildcards/wild_attack.tres")
const WILD_MOVE: CardAction = preload("res://data/wildcards/wild_move.tres")

const _CombatState = preload("res://features/combat/scene/combat_state.gd")
const _CombatPlayerActions = preload("res://features/combat/scene/combat_player_actions.gd")
const _CombatEnemyAI = preload("res://features/combat/scene/combat_enemy_ai.gd")
const _CombatTurnController = preload("res://features/combat/scene/combat_turn_controller.gd")
const _CombatRoundResolver = preload("res://features/combat/scene/combat_round_resolver.gd")
const _CombatWildcardsUI = preload("res://features/combat/scene/combat_wildcards_ui.gd")
const _CombatEnemyRevealPresentation = preload("res://features/combat/scene/combat_enemy_reveal_presentation.gd")
const Phase = _CombatTurnController.Phase
const Wild = _CombatTurnController.Wild

@onready var player_stats = $UI/MainVBox/TopBar/PlayerStats
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
@onready var plan_zone = $UI/MainVBox/HandArea/PlanZone
@onready var turn_order_bar = $UI/TurnOrderBar
@onready var monster_card_view = $UI/MonsterCardView
@onready var result_screen = $UI/ResultScreen

var state
var player_actions
var enemy_ai
var deck_manager: CombatDeckManager
var turn := _CombatTurnController.new()
var round_resolver := _CombatRoundResolver.new()
var _combat_finished := false
var _preview_action: CardActionLine = null
var wildcards_ui := _CombatWildcardsUI.new()
var _wildcards: CombatWildcards
var _result_flow: CombatResultFlow
var _damage: CombatDamageResolver
var _pile_popup: CombatPilePopup
var _turn_flow: CombatTurnFlow
var enemy_reveal := _CombatEnemyRevealPresentation.new()
var _player_name := ""
var _enemy_name := ""
var _preview_tween: Tween = null

func _enter_tree() -> void:
	# Esto corre antes del _ready de MapArea: cuando haya layouts por bioma,
	# MapArea ya tendrá el contexto al construir sus elementos.
	var combat_map := get_node_or_null("CombatWorld/MapArea") as MapArea
	if combat_map != null:
		combat_map.setup_biome(GameState.combat_biome)

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
	cam.look_at_from_position(Vector3(-5.0, 18.0, 39.0), Vector3(15.0, 0.0, 15.0), Vector3.UP)

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
	_result_flow = CombatResultFlow.new(self)
	_damage = CombatDamageResolver.new(self)
	_pile_popup = CombatPilePopup.new(self)
	_turn_flow = CombatTurnFlow.new(self)

	deck_manager = CombatDeckManager.new()
	deck_manager.setup(state)
	deck_manager.reshuffled.connect(func(): log_message(LocalizationState.t("combat.reshuffle")))

	player_actions = _CombatPlayerActions.new()
	player_actions.setup(state, map_area, _damage.deal_to_enemy, _damage.deal_to_player, _result_flow.check_combat_end)
	player_actions.log_requested.connect(log_message)
	map_area.player_knocked_off_tree.connect(player_actions.player_falls_from_tree)
	player_actions.hand_refresh_requested.connect(refresh_hand)
	player_actions.ui_update_requested.connect(update_ui)
	player_actions.card_preview_show_requested.connect(show_card_preview)
	player_actions.card_preview_hide_requested.connect(hide_card_preview)
	player_actions.confirm_popup_show_requested.connect(_on_confirm_popup_show)
	player_actions.confirm_popup_hide_requested.connect(func():
		confirm_popup.visible = false
		map_area.unlock_hover())
	player_actions.end_move_button_visible_changed.connect(func(v): end_move_button.visible = v)
	player_actions.move_mode_button_reset_requested.connect(func(): move_mode_button.button_pressed = false)

	var enemy_name_str := ""
	var wild_youn: YounData = GameState.pending_wild_youn_data
	# El combate de prueba del menú también pelea contra un Youn.
	if wild_youn == null:
		wild_youn = load("res://data/youns/pombero.tres")
	GameState.pending_wild_youn_data = null
	state.enemy_hp     = wild_youn.combat_max_hp()
	state.enemy_max_hp = state.enemy_hp
	if wild_youn.base_stats != null:
		state.enemy_status_reduction = YounStatRules.status_reduction(wild_youn.base_stats.to_dict())
	map_area.setup_enemy_youn(wild_youn)
	enemy_ai = _CombatEnemyAI.new()
	enemy_ai.setup(state, map_area, wild_youn.strategy, _damage.deal_to_enemy, _damage.deal_to_player, _result_flow.check_combat_end)
	enemy_ai.initiative = DEFAULT_ENEMY_INITIATIVE
	enemy_ai.set_monster_deck(wild_youn.monster_deck)
	enemy_name_str = wild_youn.youn_name

	enemy_ai.log_requested.connect(log_message)
	enemy_ai.card_action_started.connect(func(i): monster_card_view.highlight(i))
	enemy_ai.ui_update_requested.connect(update_ui)

	var _youn = PartyManager.youn
	if is_instance_valid(_youn) and _youn.youn_data:
		map_area.setup_player(_youn.youn_data)
		_player_name = _youn.youn_data.youn_name
	var player_stat_values := CardScaling.player_stats()
	state.player_hp = YounStatRules.max_hp(player_stat_values)
	state.player_max_hp = state.player_hp
	state.player_max_mp = YounStatRules.max_mp(player_stat_values)
	state.player_mp = state.player_max_mp
	state.player_status_reduction = YounStatRules.status_reduction(player_stat_values)
	if _player_name == "":
		_player_name = LocalizationState.t("combat.you")
	_enemy_name = enemy_name_str

	end_turn_button.pressed.connect(_turn_flow.on_end_turn_pressed)
	move_mode_button.toggled.connect(player_actions._on_move_mode_toggled)
	draw_pile_button.pressed.connect(_pile_popup.show_draw_pile)
	discard_pile_button.pressed.connect(_pile_popup.show_discard_pile)
	pile_close_button.pressed.connect(_pile_popup.close)
	confirm_yes_button.pressed.connect(player_actions._on_confirm_yes)
	confirm_no_button.pressed.connect(player_actions._on_confirm_no)
	confirm_fin_button.pressed.connect(player_actions._on_confirm_fin)
	end_move_button.pressed.connect(player_actions._on_end_move_pressed)

	if map_area.has_signal("position_selected"):
		map_area.position_selected.connect(player_actions._on_position_selected)

	hand_section.set_title(LocalizationState.t("combat.hand"))
	hand_section.card_index_selected.connect(_turn_flow.on_hand_card_selected)
	hand_section.half_selected.connect(_turn_flow.on_hand_half_selected)
	_wildcards = CombatWildcards.new(self)
	wildcards_ui.setup(hand_section, $UI, pile_popup, pile_popup_title, pile_popup_grid, {
		"none": Wild.NONE, "attack": Wild.ATTACK, "move": Wild.MOVE,
		"keep": Wild.KEEP, "item": Wild.ITEM,
	})
	wildcards_ui.wild_toggled.connect(_wildcards.on_toggled)
	wildcards_ui.skip_requested.connect(_turn_flow.on_skip_line_pressed)
	wildcards_ui.end_turn_requested.connect(_turn_flow.on_end_turn_pressed)
	wildcards_ui.keep_card_selected.connect(_wildcards.on_pile_card_selected)
	wildcards_ui.item_selected.connect(_wildcards.use_item)
	wildcards_ui.item_cancelled.connect(_wildcards.close_item_picker)
	enemy_reveal.setup($UI, monster_card_view)
	plan_zone.slot_clicked.connect(_turn_flow.on_plan_slot_clicked)
	plan_zone.slot_dropped.connect(_turn_flow.on_plan_slot_dropped)
	plan_zone.confirm_pressed.connect(func(): _turn_flow.commit_plan(turn.plan_slots[0], turn.plan_slots[1]))
	plan_zone.initiative_shift_requested.connect(_turn_flow.on_initiative_shift_requested)

	_turn_flow.setup_draw_pile()
	deck_manager.draw_cards(HAND_SIZE)
	_apply_localized_text()

	card_preview.hover_enabled = false
	card_preview.set_disabled(true)

	PauseMenu.enabled = true

	log_message(LocalizationState.t("combat.started", [enemy_name_str]))
	# Salud baja: las cartas rinden menos (ver CardScaling.health_penalty).
	if GameState.player_save != null:
		var penalty := CardScaling.health_penalty(GameState.player_save.salud)
		if penalty > 0.0:
			log_message(LocalizationState.t("combat.low_health", [roundi(penalty * 100)]))
	_turn_flow.start_planning()

func _exit_tree() -> void:
	ZoneManager.set_world_visible(true)
	PartyManager.set_party_visible(true)
	GlobalHUD.set_debug_stats_visible(true)

## Casi todo lo llama CombatTurnFlow — este passthrough existe porque también
## lo llaman directo CombatWildcards y la señal hand_refresh_requested.
func refresh_hand() -> void:
	_turn_flow.refresh_hand()

# ── Interfaz ──────────────────────────────────────────────────────────────────

func update_ui() -> void:
	player_stats.text = LocalizationState.t("combat.player_stats", [
		state.player_hp, state.player_mp, state.player_max_mp, state.player_block, state.player_ward, state.enemy_hp
	])
	map_area.set_status_texts(state.status_summary(true), state.status_summary(false))

func show_card_preview(action: CardActionLine) -> void:
	_preview_action = action
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	hand_section.show_all_cards()
	var index: int = turn.playing.get("card", -1)
	if index >= 0:
		hand_section.set_card_visible_at(index, false)
		card_preview.set_card(turn.turn_cards[index])
	card_preview.modulate.a = 0.0
	card_preview.visible = true
	_preview_tween = create_tween()
	_preview_tween.tween_property(card_preview, "modulate:a", 1.0, 0.15)

func hide_card_preview() -> void:
	_preview_action = null
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	if not card_preview.visible:
		return
	hand_section.show_all_cards()
	_preview_tween = create_tween()
	_preview_tween.tween_property(card_preview, "modulate:a", 0.0, 0.1)
	_preview_tween.tween_callback(func(): card_preview.visible = false)

func _on_confirm_popup_show(show_fin: bool) -> void:
	confirm_fin_button.visible = show_fin
	confirm_popup.visible = true
	# La vista previa queda fija donde se hizo clic mientras se confirma.
	map_area.lock_hover_at_last_click()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and card_preview.visible:
		player_actions.cancel_selection()
		get_viewport().set_input_as_handled()

func log_message(text: String) -> void:
	message_log.append_text(text + "\n")

func _apply_localized_text(_language: String = "") -> void:
	hand_section.set_title(LocalizationState.t("combat.hand" if turn.phase == Phase.PLANNING else "combat.actions"))
	move_mode_button.text = LocalizationState.t("combat.move")
	end_turn_button.text = LocalizationState.t("combat.end_turn")
	end_move_button.text = LocalizationState.t("combat.end_move")
	confirm_label.text = LocalizationState.t("combat.confirm_action")
	confirm_yes_button.text = LocalizationState.t("combat.yes")
	confirm_no_button.text = LocalizationState.t("combat.no")
	confirm_fin_button.text = LocalizationState.t("combat.finish")
	_wildcards.apply_localization()
	enemy_reveal.apply_localization()
	_pile_popup.refresh_title_if_visible()
	_turn_flow._refresh_hand_view()
	update_ui()
