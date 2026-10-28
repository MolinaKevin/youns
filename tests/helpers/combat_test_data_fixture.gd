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

static func action(type: String, score: float, conditions: Array) -> AiAction:
	var value := AiAction.new()
	value.action_type = type
	value.base_score = score
	for condition_value in conditions:
		value.conditions.append(condition_value)
	value.damage = 8
	return value
