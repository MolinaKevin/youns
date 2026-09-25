extends Node

const HAND_SIZE := 6
const DEFAULT_ENEMY_INITIATIVE := 50
## Oro que da ganar un combate (se suma al volver al mundo).
const VICTORY_GOLD := 300
## PLACEHOLDER: ganancia de stats fija que solo se muestra, no se aplica.
## Los Youns todavía no tienen stats de combate; se define después.
const PLACEHOLDER_STAT_GAINS := [["HP", 50], ["Ataque", 20], ["Defensa", 10], ["Velocidad", 10]]
## Segundos entre la muerte (del enemigo o del jugador) y la pantalla de fin de lucha.
const VICTORY_SCREEN_DELAY := 0.8
## Tamaño de la carta del enemigo mientras se revela en el centro.
const REVEAL_CARD_ZOOM := 1.5
## Segundos que se ve el orden de la ronda antes de que actúe el enemigo.
const TURN_ORDER_PAUSE := 0.8

## REVEAL: iniciativas y carta del enemigo a la vista, esperando "Comenzar ronda".
enum Phase { PLANNING, REVEAL, ENEMY, ACTING }
## Comodines: en vez de la acción impresa, la mitad se gasta con uno de estos.
## ATTACK reemplaza una ▲, MOVE una ▼ y KEEP cualquiera de las dos.
enum Wild { NONE, ATTACK, MOVE, KEEP }

const WILD_ATTACK: CardAction = preload("res://data/wildcards/wild_attack.tres")
const WILD_MOVE: CardAction = preload("res://data/wildcards/wild_move.tres")

const _CombatState = preload("res://features/combat/scene/combat_state.gd")
const _CombatPlayerActions = preload("res://features/combat/scene/combat_player_actions.gd")
const _CombatEnemyAI = preload("res://features/combat/scene/combat_enemy_ai.gd")
const _AiAction   = preload("res://data/enemies/ai_action.gd")
const _AiStrategy = preload("res://data/enemies/ai_strategy.gd")
const _EnemyData  = preload("res://data/enemies/enemy_data.gd")

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
var _combat_finished := false
var _preview_action: CardActionLine = null
var _phase := Phase.PLANNING
## Índices de state.hand ubicados en la zona de planificación (-1 = vacío).
## [0] = izquierda: marca la iniciativa. Se guardan índices porque el mazo
## puede repetir el mismo recurso.
var _plan_slots: Array[int] = [-1, -1]
## Índice en state.hand de cada carta que se muestra en la mano durante la planificación.
var _hand_view_indices: Array[int] = []
## Las 2 cartas confirmadas para este turno ([0] marcó la iniciativa).
var _turn_cards: Array[CardData] = []
## Índice en _turn_cards de la carta usada por su mitad superior / inferior (-1 = sin usar).
## Regla: una mitad ▲ y una ▼, nunca las dos de la misma carta.
var _used_top := -1
var _used_bottom := -1
## Mitad en juego, línea por línea. Vacío si no hay.
## {"card": int, "is_top": bool, "lines": Array[CardActionLine], "index": int,
##  "started": bool, "active": bool}. started = ya se hizo alguna línea (la
## mitad está gastada); active = la línea actual ya arrancó su selección.
var _playing: Dictionary = {}
## true mientras se arranca una línea: CombatPlayerActions puede pedir un
## refresh en el medio y no hay que tomarlo como cancelación.
var _starting_line := false
## Índices en state.hand de _turn_cards (se descartan al final de la ronda).
var _turn_hand_indices: Array[int] = []
var _armed_wild := Wild.NONE
var _wild_buttons: Dictionary = {}
## Panel de comodines; vive entre las dos cartas del turno (dentro de hand_section).
var wildcard_box: PanelContainer
var _wild_title: Label
## "Fin de turno" debajo de los comodines; se resalta cuando ya se usaron las dos mitades.
var _wild_end_button: Button
## "Saltar acción": saltea la línea en curso (y gasta la mitad).
var _skip_line_button: Button
## "Comenzar ronda", centrado debajo de la carta del enemigo en la revelación.
var _start_round_button: Button
## Mitad que se está gastando con "mantener carta" mientras se elige la carta.
var _keep_half: Dictionary = {}
## Índices de state.hand que no se descartan al final de la ronda.
var _kept_indices: Array[int] = []
var _enemy_pending := false
var _player_name := ""
var _enemy_name := ""
## Orden de la ronda: [{"name", "initiative", "is_player"}], menor iniciativa primero.
var _turn_order: Array[Dictionary] = []
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

	deck_manager = CombatDeckManager.new()
	deck_manager.setup(state)
	deck_manager.reshuffled.connect(func(): log_message(LocalizationState.t("combat.reshuffle")))

	player_actions = _CombatPlayerActions.new()
	player_actions.setup(state, map_area, deal_damage_to_enemy, deal_damage_to_player, check_combat_end)
	player_actions.log_requested.connect(log_message)
	player_actions.hand_refresh_requested.connect(refresh_hand)
	player_actions.ui_update_requested.connect(update_ui)
	player_actions.card_preview_show_requested.connect(show_card_preview)
	player_actions.card_preview_hide_requested.connect(hide_card_preview)
	player_actions.confirm_popup_show_requested.connect(_on_confirm_popup_show)
	player_actions.confirm_popup_hide_requested.connect(func(): confirm_popup.visible = false)
	player_actions.end_move_button_visible_changed.connect(func(v): end_move_button.visible = v)
	player_actions.move_mode_button_reset_requested.connect(func(): move_mode_button.button_pressed = false)

	var enemy_name_str := ""
	var wild_youn: YounData = GameState.pending_wild_youn_data
	if wild_youn:
		GameState.pending_wild_youn_data = null
		state.enemy_hp     = wild_youn.max_hp
		state.enemy_max_hp = wild_youn.max_hp
		map_area.set_enemy_hp(state.enemy_hp)
		map_area.setup_enemy_youn(wild_youn)
		enemy_ai = _CombatEnemyAI.new()
		enemy_ai.setup(state, map_area, wild_youn.strategy, deal_damage_to_enemy, deal_damage_to_player, check_combat_end)
		enemy_ai.initiative = DEFAULT_ENEMY_INITIATIVE
		enemy_ai.set_monster_deck(wild_youn.monster_deck)
		enemy_name_str = wild_youn.youn_name
	else:
		var enemy_data: _EnemyData = GameState.pending_enemy_data
		if enemy_data == null:
			enemy_data = load("res://data/enemies/goblin.tres")
		GameState.pending_enemy_data = null
		state.enemy_hp     = enemy_data.max_hp
		state.enemy_max_hp = enemy_data.max_hp
		map_area.set_enemy_hp(state.enemy_hp)
		map_area.setup_enemy(enemy_data.mesh, enemy_data.mesh_scale, enemy_data.combat_footprint_radius())
		enemy_ai = _CombatEnemyAI.new()
		enemy_ai.setup(state, map_area, enemy_data.strategy, deal_damage_to_enemy, deal_damage_to_player, check_combat_end)
		enemy_ai.initiative = enemy_data.initiative
		enemy_ai.set_monster_deck(enemy_data.monster_deck)
		enemy_name_str = LocalizationState.enemy_name(enemy_data.id, enemy_data.enemy_name)

	enemy_ai.log_requested.connect(log_message)
	enemy_ai.card_action_started.connect(func(i): monster_card_view.highlight(i))
	enemy_ai.ui_update_requested.connect(update_ui)

	var _youn = PartyManager.youn
	if is_instance_valid(_youn) and _youn.youn_data:
		map_area.setup_player(_youn.youn_data)
		_player_name = _youn.youn_data.youn_name
	if _player_name == "":
		_player_name = LocalizationState.t("combat.you")
	_enemy_name = enemy_name_str

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
	hand_section.card_index_selected.connect(_on_hand_card_selected)
	hand_section.half_selected.connect(_on_hand_half_selected)
	pile_popup_grid.card_selected.connect(_on_pile_card_selected)
	_build_wild_buttons()
	_start_round_button = Button.new()
	_start_round_button.custom_minimum_size = Vector2(240, 52)
	_start_round_button.add_theme_font_size_override("font_size", 20)
	_start_round_button.visible = false
	$UI.add_child(_start_round_button)
	plan_zone.slot_clicked.connect(_on_plan_slot_clicked)
	plan_zone.slot_dropped.connect(_on_plan_slot_dropped)
	plan_zone.confirm_pressed.connect(func(): _commit_plan(_plan_slots[0], _plan_slots[1]))

	setup_draw_pile()
	deck_manager.draw_cards(HAND_SIZE)
	_apply_localized_text()

	card_preview.hover_enabled = false
	card_preview.set_disabled(true)

	PauseMenu.enabled = true

	log_message(LocalizationState.t("combat.started", [enemy_name_str]))
	_start_planning()

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

func refresh_hand() -> void:
	if _phase == Phase.PLANNING:
		_hand_view_indices.clear()
		for i in state.hand.size():
			if not _plan_slots.has(i):
				_hand_view_indices.append(i)
		hand_section.drag_source = "hand"
		hand_section.halves_mode = false
		hand_section.set_cards(_hand_view_indices.map(func(i): return state.hand[i]))
	else:
		_resolve_playing()
		_update_wild_buttons()
		hand_section.drag_source = ""
		hand_section.halves_mode = true
		hand_section.set_cards(_turn_cards)
		for c in _turn_cards.size():
			for is_top in [true, false]:
				hand_section.set_half_enabled(c, is_top, _is_half_available(c, is_top))
	draw_pile_button.text = LocalizationState.t("combat.draw_pile", [state.draw_pile.size()])
	discard_pile_button.text = LocalizationState.t("combat.discard_pile", [state.discard_pile.size()])
	if _preview_action != null and not state.turn_actions.has(_preview_action):
		hide_card_preview()
	_update_plan_zone()

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
	_keep_half = {}

# ── Turn management ───────────────────────────────────────────────────────────
# Cada ronda: el jugador elige 2 cartas de la mano (superior de una + inferior
# de la otra). La iniciativa de la carta superior se compara con la del enemigo;
# menor actúa primero y el jugador gana los empates.

func _start_planning() -> void:
	_phase = Phase.PLANNING
	_plan_slots = [-1, -1]
	_turn_cards.clear()
	_playing = {}
	_disarm_wild()
	turn_order_bar.visible = false
	monster_card_view.visible = false
	monster_card_view.snap_home()
	end_turn_button.disabled = true
	move_mode_button.disabled = true
	hand_section.set_title(LocalizationState.t("combat.hand"))
	refresh_hand()
	update_ui()
	log_message(LocalizationState.t("combat.plan_hint"))

func _on_hand_card_selected(index: int) -> void:
	match _phase:
		Phase.PLANNING:
			var free := _plan_slots.find(-1)
			if free == -1:
				log_message(LocalizationState.t("combat.plan_max"))
				return
			_plan_slots[free] = _hand_view_indices[index]
			refresh_hand()

func _on_hand_half_selected(index: int, is_top: bool) -> void:
	if _phase != Phase.ACTING or not _is_half_available(index, is_top):
		return
	var half: CardAction
	var is_wild := _armed_wild != Wild.NONE
	match _armed_wild:
		Wild.KEEP:
			_start_keep(index, is_top)
			return
		Wild.ATTACK:
			half = WILD_ATTACK
		Wild.MOVE:
			half = WILD_MOVE
		_:
			half = _turn_cards[index].get_action(is_top)
	# Se juegan copias con los valores finales para las estadísticas del Youn.
	var lines := CardScaling.resolve_lines(half.enabled_lines(), CardScaling.player_stats())
	if lines.is_empty():
		log_message(LocalizationState.t("combat.no_lines"))
		return
	if is_wild:
		for line in lines:
			line.name = LocalizationState.t("wildcard.name")
	_disarm_wild()
	# Cambiar de mitad antes de hacer la primera línea no gasta nada.
	if player_actions._has_pending_selection():
		player_actions.cancel_selection()
	_playing = {"card": index, "is_top": is_top, "lines": lines, "index": 0, "started": false, "active": false}
	_start_current_line()

## Arranca la selección de objetivo de la línea actual de _playing.
func _start_current_line() -> void:
	if _playing.is_empty() or _phase != Phase.ACTING:
		return
	var line: CardActionLine = _playing["lines"][_playing["index"]]
	_starting_line = true
	_playing["active"] = true
	state.turn_actions.assign([line])
	player_actions._on_card_selected(line)
	_starting_line = false
	# Si la línea no pudo ni arrancar (p. ej. enredado), se resuelve ya.
	_resolve_playing()
	refresh_hand()

func _is_half_available(card_index: int, is_top: bool) -> bool:
	# Con una mitad empezada, hay que terminarla (o saltear sus líneas) primero.
	if not _playing.is_empty() and _playing["started"]:
		return false
	if card_index == _used_top or card_index == _used_bottom:
		return false
	if (_used_top if is_top else _used_bottom) != -1:
		return false
	match _armed_wild:
		Wild.ATTACK:
			return is_top
		Wild.MOVE:
			return not is_top
	return true

# ── Comodines ─────────────────────────────────────────────────────────────────

func _build_wild_buttons() -> void:
	wildcard_box = PanelContainer.new()
	wildcard_box.custom_minimum_size = Vector2(170, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.12, 0.92)
	style.border_color = Color(0.35, 0.85, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	wildcard_box.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	wildcard_box.add_child(column)
	hand_section.set_middle_control(wildcard_box)
	_wild_title = Label.new()
	_wild_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_wild_title)
	for w in [Wild.ATTACK, Wild.MOVE, Wild.KEEP]:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_constant_override("icon_max_width", 22)
		# Ícono y texto juntos a la izquierda: "⚔ ▲ 2".
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("h_separation", 8)
		b.toggled.connect(_on_wild_toggled.bind(w))
		column.add_child(b)
		_wild_buttons[w] = b
	var separator := HSeparator.new()
	column.add_child(separator)
	_skip_line_button = Button.new()
	_skip_line_button.custom_minimum_size = Vector2(0, 40)
	_skip_line_button.pressed.connect(_on_skip_line_pressed)
	column.add_child(_skip_line_button)
	_wild_end_button = Button.new()
	_wild_end_button.custom_minimum_size = Vector2(0, 44)
	_wild_end_button.pressed.connect(_on_end_turn_pressed)
	column.add_child(_wild_end_button)
	wildcard_box.visible = false

func _wild_texts() -> void:
	_wild_title.text = LocalizationState.t("combat.wildcards")
	# Mismos íconos que las cartas: ▲ espada + daño, ▼ bota + casillas, ▲▼ marcador.
	# El texto largo queda en el tooltip.
	var attack: int = WILD_ATTACK.lines[0].damage
	var move: int = WILD_MOVE.lines[0].card_range
	_set_wild_button(Wild.ATTACK, "sword", "▲  %d" % attack, LocalizationState.t("wildcard.attack", [attack]))
	_set_wild_button(Wild.MOVE, "move", "▼  %d" % move, LocalizationState.t("wildcard.move", [move]))
	_set_wild_button(Wild.KEEP, "keep", "▲▼  " + LocalizationState.t("wildcard.keep"), LocalizationState.t("wildcard.keep"))
	_wild_end_button.text = LocalizationState.t("combat.end_turn")
	_skip_line_button.text = LocalizationState.t("combat.skip_line")

func _set_wild_button(wild: Wild, icon_key: String, text: String, tooltip: String) -> void:
	var b: Button = _wild_buttons[wild]
	b.icon = CardText.icon(icon_key)
	b.text = text
	b.tooltip_text = tooltip

func _on_wild_toggled(pressed: bool, wild: Wild) -> void:
	if pressed:
		_armed_wild = wild
		for w in _wild_buttons:
			if w != wild:
				_wild_buttons[w].set_pressed_no_signal(false)
		log_message(LocalizationState.t("combat.wild_armed"))
	elif _armed_wild == wild:
		_armed_wild = Wild.NONE
	refresh_hand()

func _disarm_wild() -> void:
	_armed_wild = Wild.NONE
	for w in _wild_buttons:
		_wild_buttons[w].set_pressed_no_signal(false)

## Cada comodín se habilita solo si queda una mitad del tipo que reemplaza.
func _update_wild_buttons() -> void:
	wildcard_box.visible = _phase == Phase.ACTING
	var busy: bool = not _playing.is_empty() and _playing["started"]
	var usable := {
		Wild.ATTACK: _used_top == -1 and not busy,
		Wild.MOVE: _used_bottom == -1 and not busy,
		Wild.KEEP: (_used_top == -1 or _used_bottom == -1) and not busy and not _keep_candidates().is_empty(),
	}
	for w in _wild_buttons:
		_wild_buttons[w].disabled = not usable[w]
	_skip_line_button.disabled = _playing.is_empty() or not _playing["active"]
	var both_used := _used_top != -1 and _used_bottom != -1
	_wild_end_button.modulate = Color(1.0, 0.85, 0.35) if both_used else Color.WHITE
	if _armed_wild != Wild.NONE and not usable[_armed_wild]:
		_disarm_wild()

## Cartas de la mano que se pueden mantener: las que no se juegan este turno.
func _keep_candidates() -> Array[int]:
	var result: Array[int] = []
	for i in state.hand.size():
		if not _turn_hand_indices.has(i) and not _kept_indices.has(i):
			result.append(i)
	return result

func _start_keep(card_index: int, is_top: bool) -> void:
	if player_actions._has_pending_selection():
		player_actions.cancel_selection()
	_keep_half = {"card": card_index, "is_top": is_top}
	var cards: Array[CardData] = []
	for i in _keep_candidates():
		cards.append(state.hand[i])
	pile_popup_title.text = LocalizationState.t("combat.keep_title")
	pile_popup_grid.set_cards(cards)
	pile_popup.visible = true

func _on_pile_card_selected(card: CardData) -> void:
	if _keep_half.is_empty():
		return
	for i in _keep_candidates():
		if state.hand[i] == card:
			_kept_indices.append(i)
			break
	if _keep_half["is_top"]:
		_used_top = _keep_half["card"]
	else:
		_used_bottom = _keep_half["card"]
	log_message(LocalizationState.t("combat.kept", [LocalizationState.card_name(card.id, card.name)]))
	pile_popup.visible = false
	_keep_half = {}
	_disarm_wild()
	refresh_hand()

## La mitad en juego queda gastada (una vez hecha o salteada alguna línea).
func _mark_playing_started() -> void:
	if _playing["started"]:
		return
	_playing["started"] = true
	if _playing["is_top"]:
		_used_top = _playing["card"]
	else:
		_used_bottom = _playing["card"]

## "Saltar acción": gasta la mitad y cancela la línea en curso; _resolve_playing
## la toma como salteada y arranca la siguiente.
func _on_skip_line_pressed() -> void:
	if _phase != Phase.ACTING or _playing.is_empty() or not _playing["active"]:
		return
	_mark_playing_started()
	player_actions.cancel_selection()

## Sigue el avance de la mitad en juego. CombatPlayerActions saca la línea de
## state.turn_actions cuando la ejecuta:
##  - línea hecha → la mitad queda gastada y se pasa a la siguiente línea;
##  - línea cancelada (o que no pudo hacerse) → si la mitad ya estaba empezada
##    se saltea la línea; si no, se abandona la mitad sin gastarla.
func _resolve_playing() -> void:
	if _playing.is_empty() or _starting_line or not _playing["active"]:
		return
	var line: CardActionLine = _playing["lines"][_playing["index"]]
	var done: bool = not state.turn_actions.has(line)
	if done:
		_mark_playing_started()
	if player_actions._has_pending_selection():
		return  # sigue en curso (p. ej. un movimiento con alcance restante)
	if not done:
		if not _playing["started"]:
			_playing = {}
			state.turn_actions.clear()
			return
		log_message(LocalizationState.t("combat.line_skipped"))
	_playing["index"] += 1
	_playing["active"] = false
	if _playing["index"] >= _playing["lines"].size():
		_playing = {}
		state.turn_actions.clear()
		return
	# Diferido: CombatPlayerActions todavía puede estar terminando la línea anterior.
	_start_current_line.call_deferred()

func _on_plan_slot_clicked(slot: int) -> void:
	if _phase != Phase.PLANNING:
		return
	_plan_slots[slot] = -1
	refresh_hand()

func _on_plan_slot_dropped(slot: int, data: Dictionary) -> void:
	if _phase != Phase.PLANNING:
		return
	match data.get("source"):
		"hand":
			# La carta que estaba en el espacio vuelve sola a la mano.
			_plan_slots[slot] = _hand_view_indices[data["index"]]
		"slot":
			var from: int = data["index"]
			var moved := _plan_slots[from]
			_plan_slots[from] = _plan_slots[slot]
			_plan_slots[slot] = moved
	refresh_hand()

func _update_plan_zone() -> void:
	plan_zone.visible = _phase == Phase.PLANNING
	if not plan_zone.visible:
		return
	var cards := _plan_slots.map(func(i): return state.hand[i] if i >= 0 else null)
	var initiative: int = cards[0].initiative if cards[0] != null else -1
	# Con mazo, la carta del enemigo (y su iniciativa) se revela al confirmar.
	var enemy_initiative := "?" if enemy_ai.monster_deck != null else str(enemy_ai.initiative)
	plan_zone.set_state(cards, initiative, enemy_initiative)

func _commit_plan(lead_index: int, second_index: int) -> void:
	_turn_cards.assign([state.hand[lead_index], state.hand[second_index]])
	_turn_hand_indices.assign([lead_index, second_index])
	_used_top = -1
	_used_bottom = -1
	_playing = {}
	state.turn_actions.clear()

	var player_initiative := _turn_cards[0].initiative
	var monster_card: MonsterCard = enemy_ai.draw_card()
	log_message(LocalizationState.t("combat.initiative", [player_initiative, enemy_ai.initiative]))
	hand_section.set_title(LocalizationState.t("combat.actions"))
	_build_turn_order(player_initiative)
	var enemy_first: bool = not _turn_order[0]["is_player"]
	# Si el enemigo no va primero, actúa cuando el jugador termina su turno.
	_enemy_pending = not enemy_first
	log_message(LocalizationState.t("combat.enemy_first" if enemy_first else "combat.player_first"))

	# Todo revelado: se espera a que el jugador arranque la ronda.
	_phase = Phase.REVEAL
	refresh_hand()
	turn_order_bar.show_order(_turn_order, -1)
	await _reveal_and_wait(monster_card)

	if enemy_first:
		_phase = Phase.ENEMY
		turn_order_bar.show_order(_turn_order, 0)
		await enemy_ai.take_turn()
		if check_combat_end():
			return

	turn_order_bar.show_order(_turn_order, _turn_order.find_custom(func(e): return e["is_player"]))
	_phase = Phase.ACTING
	end_turn_button.disabled = false
	move_mode_button.disabled = false
	refresh_hand()
	update_ui()
	log_message(LocalizationState.t("combat.acting_hint"))

## Muestra la carta del enemigo grande en el centro con "Comenzar ronda" debajo,
## espera el botón y manda la carta a su lugar de arriba a la izquierda.
func _reveal_and_wait(monster_card: MonsterCard) -> void:
	var screen := get_viewport().get_visible_rect().size
	var button_y := screen.y * 0.5
	if monster_card != null:
		monster_card_view.show_card(monster_card, enemy_ai.monster_deck)
		await get_tree().process_frame  # que el panel calcule su tamaño
		var center := Vector2(screen.x * 0.5, screen.y * 0.36)
		monster_card_view.present_at(center, REVEAL_CARD_ZOOM)
		button_y = center.y + monster_card_view.size.y * REVEAL_CARD_ZOOM * 0.5 + 24.0
	_start_round_button.text = LocalizationState.t("combat.start_round")
	_start_round_button.reset_size()
	_start_round_button.position = Vector2(screen.x * 0.5 - _start_round_button.size.x * 0.5, button_y)
	_start_round_button.visible = true
	await _start_round_button.pressed
	_start_round_button.visible = false
	if monster_card != null:
		await monster_card_view.return_home()

## Ordena a los personajes por iniciativa (menor primero; en empate va el jugador).
func _build_turn_order(player_initiative: int) -> void:
	_turn_order.assign([
		{"name": _player_name, "initiative": player_initiative, "is_player": true},
		{"name": _enemy_name, "initiative": enemy_ai.initiative, "is_player": false},
	])
	_turn_order.sort_custom(func(a, b):
		if a["initiative"] != b["initiative"]:
			return a["initiative"] < b["initiative"]
		return a["is_player"] and not b["is_player"])

func _on_end_turn_pressed() -> void:
	if _phase != Phase.ACTING:
		return
	_phase = Phase.ENEMY
	end_turn_button.disabled = true
	move_mode_button.disabled = true
	player_actions.reset()
	state.turn_actions.clear()
	_turn_cards.clear()
	_playing = {}
	_keep_half = {}
	pile_popup.visible = false
	_disarm_wild()
	refresh_hand()
	if _enemy_pending:
		turn_order_bar.show_order(_turn_order, _turn_order.find_custom(func(e): return not e["is_player"]))
		await get_tree().create_timer(TURN_ORDER_PAUSE).timeout
		await enemy_ai.take_turn()
		if check_combat_end():
			return
	await reset_turn()
	if state.player_hp <= 0 or state.enemy_hp <= 0:
		return
	_start_planning()

func reset_turn() -> void:
	if state.player_burning_turns > 0:
		log_message("¡Estás en llamas! %d de daño." % CombatState.BURN_DAMAGE)
		await deal_damage_to_player(CombatState.BURN_DAMAGE, true)
		if check_combat_end(): return
		state.player_burning_turns -= 1
		if state.player_burning_turns == 0:
			log_message("Ya no estás en llamas.")

	if state.player_bleeding_turns > 0:
		log_message("¡Estás sangrando! %d de daño." % CombatState.BLEED_DAMAGE)
		await deal_damage_to_player(CombatState.BLEED_DAMAGE, true)
		if check_combat_end(): return
		state.player_bleeding_turns -= 1
		if state.player_bleeding_turns == 0:
			log_message("Ya no estás sangrando.")

	if state.player_poison_stacks > 0:
		var pdmg: int = state.player_poison_stacks * CombatState.POISON_DAMAGE_PER_STACK
		log_message("¡Estás envenenado! %d de daño." % pdmg)
		await deal_damage_to_player(pdmg, true)
		if check_combat_end(): return
		state.player_poison_stacks -= 1
		if state.player_poison_stacks == 0:
			log_message("El veneno se disipó.")

	if state.player_wet_turns > 0:
		state.player_wet_turns -= 1
		if state.player_wet_turns == 0:
			log_message("Ya no estás mojado.")

	if state.player_greasy_turns > 0:
		state.player_greasy_turns -= 1
		if state.player_greasy_turns == 0:
			log_message("Ya no estás engrasado.")

	if state.player_entangled_turns > 0:
		state.player_entangled_turns -= 1
		if state.player_entangled_turns == 0:
			log_message("Ya no estás enredado.")

	if state.player_blinded_turns > 0:
		state.player_blinded_turns -= 1
		if state.player_blinded_turns == 0:
			log_message("Ya no estás cegado.")

	if state.player_frozen_turns > 0:
		state.player_frozen_turns -= 1
		if state.player_frozen_turns == 0:
			log_message("Ya no estás congelado.")

	player_actions.reset()
	deck_manager.reset_turn(HAND_SIZE, _kept_indices)
	_kept_indices.clear()
	_turn_hand_indices.clear()
	refresh_hand()
	update_ui()

# ── Damage ────────────────────────────────────────────────────────────────────

func deal_damage_to_enemy(amount: int, skip_attack_anim: bool = false) -> void:
	var dmg: int = max(amount - state.enemy_block, 0)
	state.enemy_block = max(state.enemy_block - amount, 0)
	state.enemy_hp -= dmg
	if map_area.has_method("set_enemy_hp"):
		map_area.set_enemy_hp(state.enemy_hp)
	if not skip_attack_anim:
		await _play_player_anim_timed("attack")
	await _play_enemy_anim_timed("damage")

func deal_damage_to_player(amount: int, skip_attack_anim: bool = false) -> void:
	var dmg: int = max(amount - state.player_block, 0)
	state.player_block = max(state.player_block - amount, 0)
	state.player_hp -= dmg
	if dmg > 0 and state.player_overwatch_active:
		state.player_overwatch_active = false
		map_area.clear_overwatch_zone()
		log_message("Vigilancia cancelada por recibir daño.")
	if not skip_attack_anim:
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
		state.player_hp, state.player_block, state.enemy_hp
	])
func check_combat_end() -> bool:
	if state.enemy_hp <= 0:
		hand_section.disable_cards()
		end_turn_button.disabled = true
		if not _combat_finished:
			_combat_finished = true
			log_message(LocalizationState.t("combat.win"))
			_show_victory.call_deferred()
		return true
	if state.player_hp <= 0:
		hand_section.disable_cards()
		end_turn_button.disabled = true
		if not _combat_finished:
			_combat_finished = true
			log_message(LocalizationState.t("combat.lose"))
			map_area.play_player_anim("die")
			_show_defeat.call_deferred()
		return true
	return false

func show_card_preview(action: CardActionLine) -> void:
	_preview_action = action
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	hand_section.show_all_cards()
	var index: int = _playing.get("card", -1)
	if index >= 0:
		hand_section.set_card_visible_at(index, false)
		card_preview.set_card(_turn_cards[index])
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and card_preview.visible:
		player_actions.cancel_selection()
		get_viewport().set_input_as_handled()

func log_message(text: String) -> void:
	message_log.append_text(text + "\n")

## Muestra la pantalla de fin de lucha y, al continuar, vuelve al mundo.
func _show_victory() -> void:
	await _prepare_result_screen()
	var gold := VICTORY_GOLD if GameState.combat_return_pending else 0
	result_screen.show_victory(PLACEHOLDER_STAT_GAINS, gold)
	await result_screen.continue_pressed
	if GameState.combat_return_pending:
		GameState.player_save.gold += gold
		GameState.save_player_save()
	_leave_combat()

## PLACEHOLDER de derrota: sin penalidad todavía. Se vuelve al mundo igual que
## al ganar (el enemigo del mundo huye, así no te vuelve a atrapar al aparecer).
func _show_defeat() -> void:
	await _prepare_result_screen()
	result_screen.show_defeat()
	await result_screen.continue_pressed
	_leave_combat()

func _prepare_result_screen() -> void:
	_start_round_button.visible = false
	wildcard_box.visible = false
	await get_tree().create_timer(VICTORY_SCREEN_DELAY).timeout

func _leave_combat() -> void:
	if not GameState.combat_return_pending:
		# Combate abierto directo desde el editor: no hay mundo al que volver.
		get_tree().reload_current_scene()
		return
	get_tree().change_scene_to_file("res://features/world/game_world/game_world.tscn")

func _apply_localized_text(_language: String = "") -> void:
	hand_section.set_title(LocalizationState.t("combat.hand" if _phase == Phase.PLANNING else "combat.actions"))
	move_mode_button.text = LocalizationState.t("combat.move")
	end_turn_button.text = LocalizationState.t("combat.end_turn")
	end_move_button.text = LocalizationState.t("combat.end_move")
	confirm_label.text = LocalizationState.t("combat.confirm_action")
	confirm_yes_button.text = LocalizationState.t("combat.yes")
	confirm_no_button.text = LocalizationState.t("combat.no")
	confirm_fin_button.text = LocalizationState.t("combat.finish")
	_wild_texts()
	refresh_hand()
	update_ui()
