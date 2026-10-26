class_name CombatEnemyCardAi
extends RefCounted

## Con mazo, cada ronda el enemigo roba una carta (MonsterDeck) y ejecuta sus
## acciones en orden. Es una de las dos "IA" de CombatEnemyAI — la otra es
## CombatEnemyStrategyAi (fases/condiciones), para enemigos sin mazo. `host`
## es el CombatEnemyAI dueño exclusivo de esta instancia.

## Cuántas cartas mira el enemigo cada ronda para elegir la suya.
const ROUND_OPTIONS := 3

var host: CombatEnemyAI
var _card_pile: Array[MonsterCard] = []

func _init(p_host: CombatEnemyAI) -> void:
	host = p_host

func clear_pile() -> void:
	_card_pile.clear()

## Roba la carta de la ronda y toma su iniciativa: mira ROUND_OPTIONS cartas
## del mazo y se queda con una (choose_card). Solo se gasta la elegida.
## Si quedan menos de ROUND_OPTIONS por usar, se vuelve a mezclar el mazo entero
## (las que quedaban se juntan con las usadas), así siempre hay 3 opciones.
func draw_card() -> MonsterCard:
	host.round_options.clear()
	if host.monster_deck == null or host.monster_deck.cards.is_empty():
		host.current_card = null
		return null
	if _card_pile.size() < ROUND_OPTIONS:
		_card_pile.assign(host.monster_deck.cards)
		_card_pile.shuffle()
	var count := mini(ROUND_OPTIONS, _card_pile.size())
	host.round_options.assign(_card_pile.slice(_card_pile.size() - count))
	host.current_card = choose_card(host.round_options)
	_card_pile.erase(host.current_card)
	host.initiative = host.current_card.initiative
	return host.current_card

## Elige la carta de la ronda entre las opciones. PROVISORIO: al azar. Acá va a
## ir la inteligencia de los enemigos.
func choose_card(options: Array[MonsterCard]) -> MonsterCard:
	return options.pick_random()

func execute_card(card: MonsterCard) -> void:
	CombatLog.emit_requested(host.log_requested, "combat.log.enemy_card.played", [LocalizationState.t("combat.enemy"), card.card_name])
	for i in card.actions.size():
		host.card_action_started.emit(i)
		await _execute_card_action(card, i)
		if host.check_combat_end.call():
			return
		host.ui_update_requested.emit()
		if host.action_delay > 0.0:
			await (Engine.get_main_loop() as SceneTree).create_timer(host.action_delay).timeout
	host.card_action_started.emit(-1)

func _execute_card_action(card: MonsterCard, index: int) -> void:
	var action: MonsterCardAction = card.actions[index]
	match action.type:
		"move":
			# Si ya está al alcance del próximo ataque de la carta, no se mueve.
			var next_attack := _next_attack(card, index)
			if next_attack != null and host._player_in_reach(host.monster_deck.reach_for(next_attack)):
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy_card.holds_position")
				return
			var amount := host.monster_deck.move_for(action)
			if amount > 0:
				await host._move_enemy(host.map_area.player_pos, host.w(amount), "combat.log.enemy_card.moves_forward", [amount])
		"retreat":
			var amount := host.monster_deck.move_for(action)
			if amount > 0:
				await host._move_enemy(host._retreat_target(host.w(amount)), host.w(amount), "combat.log.enemy_card.retreats", [amount])
		"attack":
			var reach := host.monster_deck.reach_for(action)
			if host.state.enemy_blinded_turns > 0:
				reach = mini(reach, MonsterDeck.MELEE_REACH_CELLS)
			if not host._player_in_reach(reach):
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy_card.attack_out_of_range")
				return
			if host.state.player_in_tree:
				CombatLog.emit_requested(host.log_requested, "combat.log.enemy.cannot_reach_tree")
				return
			var dmg := host.monster_deck.attack_for(action)
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy_card.attacks", [dmg])
			await host.deal_damage_to_player.call(dmg, false, action.damage_type)
			await host._try_player_counter()
		"block":
			host.state.enemy_block += action.value
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy_card.blocks", [action.value])
		"ward":
			host.state.enemy_ward += action.value
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy.ward", [action.value])
		"heal":
			var before: int = host.state.enemy_hp
			host.state.enemy_hp = mini(host.state.enemy_max_hp, host.state.enemy_hp + action.value)
			CombatLog.emit_requested(host.log_requested, "combat.log.enemy_card.heals", [host.state.enemy_hp - before])
		_:
			push_warning("CombatEnemyAI: acción de carta desconocida '%s'" % action.type)

func _next_attack(card: MonsterCard, from_index: int) -> MonsterCardAction:
	for i in range(from_index + 1, card.actions.size()):
		if card.actions[i].type == "attack":
			return card.actions[i]
	return null
