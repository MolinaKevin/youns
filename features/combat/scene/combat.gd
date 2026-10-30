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

const _CombatTurnController = preload("res://features/combat/scene/combat_turn_controller.gd")
const _CombatRoundResolver = preload("res://features/combat/scene/combat_round_resolver.gd")
const _CombatWildcardsUI = preload("res://features/combat/scene/combat_wildcards_ui.gd")
const _CombatEnemyRevealPresentation = preload("res://features/combat/scene/combat_enemy_reveal_presentation.gd")
const _CombatSceneBootstrap = preload("res://features/combat/scene/combat_scene_bootstrap.gd")
const _CombatRuntimeBootstrap = preload("res://features/combat/scene/combat_runtime_bootstrap.gd")
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
@warning_ignore("unused_private_class_variable")
var _combat_finished := false
var _preview_action: CardActionLine = null
var wildcards_ui := _CombatWildcardsUI.new()
var _wildcards: CombatWildcards
@warning_ignore("unused_private_class_variable")
var _result_flow: CombatResultFlow
@warning_ignore("unused_private_class_variable")
var _damage: CombatDamageResolver
var _pile_popup: CombatPilePopup
var _turn_flow: CombatTurnFlow
var enemy_reveal := _CombatEnemyRevealPresentation.new()
@warning_ignore("unused_private_class_variable")
var _player_name := ""
var _enemy_name := ""
var _preview_tween: Tween = null
var _flow_token: AsyncFlowToken
var board: CombatBoardContext
var _scene_bootstrap: CombatSceneBootstrap
var _runtime_bootstrap: CombatRuntimeBootstrap

func _enter_tree() -> void:
	_scene_bootstrap = _CombatSceneBootstrap.new(self)
	_scene_bootstrap.enter_tree()

func _ready() -> void:
	_flow_token = AsyncFlowToken.new(self)
	if _scene_bootstrap == null:
		_scene_bootstrap = _CombatSceneBootstrap.new(self)
	_scene_bootstrap.ready_environment()
	LocalizationState.language_changed.connect(_apply_localized_text)
	randomize()
	_runtime_bootstrap = _CombatRuntimeBootstrap.new()
	_runtime_bootstrap.setup(self)

	end_turn_button.pressed.connect(_turn_flow.on_end_turn_pressed)
	move_mode_button.toggled.connect(player_actions.set_move_mode)
	draw_pile_button.pressed.connect(_pile_popup.show_draw_pile)
	discard_pile_button.pressed.connect(_pile_popup.show_discard_pile)
	pile_close_button.pressed.connect(_pile_popup.close)
	confirm_yes_button.pressed.connect(player_actions.confirm_selection)
	confirm_no_button.pressed.connect(player_actions.reject_confirmation)
	confirm_fin_button.pressed.connect(player_actions.finish_selection)
	end_move_button.pressed.connect(player_actions.finish_movement)

	map_area.scene.position_selected.connect(player_actions.select_position)

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

	log_message(LocalizationState.t("combat.started", [_enemy_name]))
	# Salud baja: las cartas rinden menos (ver CardScaling.health_penalty).
	if GameState.save_service.player_save != null:
		var penalty := CardScaling.health_penalty(GameState.save_service.player_save.salud)
		if penalty > 0.0:
			log_message(LocalizationState.t("combat.low_health", [roundi(penalty * 100)]))
	_turn_flow.start_planning()

func _exit_tree() -> void:
	if _flow_token:
		_flow_token.cancel()
	ZoneManager.set_world_visible(true)
	PartyManager.set_party_visible(true)
	GlobalHUD.set_debug_stats_visible(true)


## Cada secuencia de ronda conserva su token. Al comenzar una nueva se invalida
## cualquier continuación diferida de la anterior.
func begin_flow() -> AsyncFlowToken:
	if _flow_token:
		_flow_token.cancel()
	_flow_token = AsyncFlowToken.new(self)
	return _flow_token


func current_flow() -> AsyncFlowToken:
	return _flow_token


func is_flow_active(flow: AsyncFlowToken) -> bool:
	return is_inside_tree() and flow != null and flow == _flow_token and flow.is_active()

## Punto de entrada de compatibilidad para CombatWildcards y la señal
## hand_refresh_requested; la lógica vive en CombatTurnFlow.
func refresh_hand() -> void:
	_turn_flow.refresh_hand()

# ── Interfaz ──────────────────────────────────────────────────────────────────

func update_ui() -> void:
	player_stats.text = LocalizationState.t("combat.player_stats", [
		state.player_hp, state.player_mp, state.player_max_mp, state.player_block, state.player_ward, state.enemy_hp
	])
	map_area.scene.presentation.set_status_texts(state.status_summary(true), state.status_summary(false))

func show_card_preview(action: CardActionLine) -> void:
	_preview_action = action
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	hand_section.show_all_cards()
	var index: int = turn.playing.card if turn.playing != null else -1
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
	map_area.scene.input.lock_hover_at_last_click()

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
	_turn_flow.refresh_hand_view()
	update_ui()
