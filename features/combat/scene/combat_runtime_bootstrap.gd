class_name CombatRuntimeBootstrap
extends RefCounted

## Construye el estado y los servicios de una partida de combate.
## La escena conserva la coordinación visual; este objeto concentra el runtime.

const _CombatState = preload("res://features/combat/scene/combat_state.gd")
const _CombatPlayerActions = preload("res://features/combat/scene/combat_player_actions.gd")
const _CombatEnemyAI = preload("res://features/combat/scene/combat_enemy_ai.gd")

func setup(host) -> void:
	host.state = _CombatState.new()
	host.board = CombatBoardContext.new(host.map_area.state, host.map_area.queries, host.map_area.actors,
		host.map_area.selection, host.map_area.placement, host.map_area.effects, host.map_area.obstacles,
		host.map_area.push, host.map_area.presentation, host.map_area.movement, host.map_area.terrain, host.map_area.scene)
	host._result_flow = CombatResultFlow.new(host)
	host._damage = CombatDamageResolver.new(host)
	host._pile_popup = CombatPilePopup.new(host)
	host._turn_flow = CombatTurnFlow.new(host)

	host.deck_manager = CombatDeckManager.new()
	host.deck_manager.setup(host.state)
	host.deck_manager.reshuffled.connect(func(): host.log_message(LocalizationState.t("combat.reshuffle")))

	host.player_actions = _CombatPlayerActions.new()
	host.player_actions.setup(host.state, host.map_area, host._damage.deal_to_enemy, host._damage.deal_to_player,
		host._result_flow.check_combat_end, host.current_flow, host.is_flow_active)
	host.player_actions.log_requested.connect(host.log_message)
	host.map_area.scene.player_knocked_off_tree.connect(host.player_actions.player_falls_from_tree)
	host.player_actions.hand_refresh_requested.connect(host.refresh_hand)
	host.player_actions.ui_update_requested.connect(host.update_ui)
	host.player_actions.card_preview_show_requested.connect(host.show_card_preview)
	host.player_actions.card_preview_hide_requested.connect(host.hide_card_preview)
	host.player_actions.confirm_popup_show_requested.connect(host._on_confirm_popup_show)
	host.player_actions.confirm_popup_hide_requested.connect(func():
		host.confirm_popup.visible = false
		host.map_area.scene.input.unlock_hover())
	host.player_actions.end_move_button_visible_changed.connect(func(v): host.end_move_button.visible = v)
	host.player_actions.move_mode_button_reset_requested.connect(func(): host.move_mode_button.button_pressed = false)

	_setup_enemy(host)
	_setup_player(host)

func _setup_enemy(host) -> void:
	var wild_youn: YounData = GameState.world_combat.take_wild_youn_data()
	if wild_youn == null:
		wild_youn = load("res://data/youns/newen.tres")
	host.state.enemy_hp = wild_youn.combat_max_hp()
	host.state.enemy_max_hp = host.state.enemy_hp
	if wild_youn.base_stats != null:
		host.state.enemy_status_reduction = YounStatRules.status_reduction(wild_youn.base_stats.to_dict())
	host.map_area.scene.actors.setup_enemy(wild_youn)
	host.enemy_ai = _CombatEnemyAI.new()
	host.enemy_ai.setup_with_board(host.state, CombatEnemyBoardMapAdapter.new(host.map_area), wild_youn.strategy,
		host._damage.deal_to_enemy, host._damage.deal_to_player, host._result_flow.check_combat_end)
	host.enemy_ai.initiative = host.DEFAULT_ENEMY_INITIATIVE
	host.enemy_ai.set_monster_deck(wild_youn.monster_deck)
	host.enemy_ai.log_requested.connect(host.log_message)
	host.enemy_ai.card_action_started.connect(func(i): host.monster_card_view.highlight(i))
	host.enemy_ai.ui_update_requested.connect(host.update_ui)
	host._enemy_name = wild_youn.youn_name

func _setup_player(host) -> void:
	var youn = PartyManager.youn
	if is_instance_valid(youn) and youn.youn_data:
		host.map_area.scene.actors.setup_player(youn.youn_data)
		host._player_name = youn.youn_data.youn_name
	var player_stat_values := CardScaling.player_stats()
	var lab_hp_bonus := GameState.save_service.player_save.lab_max_hp_bonus if GameState.save_service.player_save else 0
	host.state.player_hp = YounStatRules.max_hp(player_stat_values, lab_hp_bonus)
	host.state.player_max_hp = host.state.player_hp
	host.state.player_max_mp = YounStatRules.max_mp(player_stat_values)
	host.state.player_mp = host.state.player_max_mp
	host.state.player_status_reduction = YounStatRules.status_reduction(player_stat_values)
	if host._player_name == "":
		host._player_name = LocalizationState.t("combat.you")
