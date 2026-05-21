extends GutTest

var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()
	save.gold = 100
	save.owned_card_ids = ["strike"]
	save.inventory_items = []


# ── GOLD ──────────────────────────────────────────────────────────────────────

func test_give_gold_increases_gold() -> void:
	var effect := ItemEffectGive.new()
	effect.give_type = ItemEffectGive.GiveType.GOLD
	effect.amount = 50
	effect.apply(save)
	assert_eq(save.gold, 150)


func test_give_gold_accumulates_on_multiple_calls() -> void:
	var effect := ItemEffectGive.new()
	effect.give_type = ItemEffectGive.GiveType.GOLD
	effect.amount = 25
	effect.apply(save)
	effect.apply(save)
	assert_eq(save.gold, 150)


# ── CARD ──────────────────────────────────────────────────────────────────────

func test_give_card_adds_new_card() -> void:
	var effect := ItemEffectGive.new()
	effect.give_type = ItemEffectGive.GiveType.CARD
	effect.give_id = "slash"
	effect.apply(save)
	assert_has(save.owned_card_ids, "slash")


func test_give_card_does_not_duplicate_existing_card() -> void:
	var effect := ItemEffectGive.new()
	effect.give_type = ItemEffectGive.GiveType.CARD
	effect.give_id = "strike"
	effect.apply(save)
	var count := save.owned_card_ids.filter(func(id): return id == "strike").size()
	assert_eq(count, 1)


func test_give_card_with_empty_id_does_nothing() -> void:
	var effect := ItemEffectGive.new()
	effect.give_type = ItemEffectGive.GiveType.CARD
	effect.give_id = ""
	effect.apply(save)
	assert_eq(save.owned_card_ids.size(), 1)
