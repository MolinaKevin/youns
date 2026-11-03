class_name CombatTestDataFixture
extends RefCounted

static func card(type: String, block: int = 0, damage: int = 0) -> CardActionLine:
	var value := CardActionLine.new()
	value.card_type = type
	value.block_amount = block
	value.damage = damage
	value.name = "TestCard"
	return value

static func monster_action(type: String, value: int = 0, range_mod: int = 0) -> MonsterCardAction:
	var action := MonsterCardAction.new()
	action.type = type
	action.value = value
	action.range_modifier = range_mod
	return action

static func monster_card(initiative: int, actions: Array) -> MonsterCard:
	var card := MonsterCard.new()
	card.card_name = "Test"
	card.initiative = initiative
	card.actions.assign(actions)
	return card

static func monster_deck(cards: Array, base_move := 63, base_attack := 6, base_range := 0) -> MonsterDeck:
	var deck := MonsterDeck.new()
	deck.base_move = base_move
	deck.base_attack = base_attack
	deck.base_range = base_range
	deck.cards.assign(cards)
	return deck

static func condition(type: String, check_range: float = 12.0) -> AiCondition:
	var value := AiCondition.new()
	value.type = type
	value.check_range = check_range
	return value

static func action(type: String, score: float, conditions: Array,
		score_multiplier_low_hp: float = 1.0, block_amount: int = 0) -> AiAction:
	var value := AiAction.new()
	value.action_type = type
	value.base_score = score
	for condition_value in conditions:
		value.conditions.append(condition_value)
	value.damage = 8
	value.score_multiplier_low_hp = score_multiplier_low_hp
	value.block_amount = block_amount
	return value

static func phase(phase_name: String, actions: Array) -> AiPhase:
	var value := AiPhase.new()
	value.phase_name = phase_name
	for action_value in actions:
		value.actions.append(action_value)
	return value

static func phase_transition(from: String, to: String, conditions: Array) -> AiPhaseTransition:
	var value := AiPhaseTransition.new()
	value.from_phase = from
	value.target_phase = to
	for condition_value in conditions:
		value.conditions.append(condition_value)
	return value

static func phase_strategy(initial: String, phases: Array, transitions: Array = []) -> AiStrategy:
	var value := AiStrategy.new()
	value.initial_phase = initial
	for phase_value in phases:
		value.phases.append(phase_value)
	for transition_value in transitions:
		value.transitions.append(transition_value)
	return value
