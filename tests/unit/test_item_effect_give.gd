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


# ── ITEM ──────────────────────────────────────────────────────────────────────

func _make_item(id: String) -> ItemData:
	var d := ItemData.new()
	d.id = id
	d.name = id
	return d


func _make_effect(amount: int) -> ItemEffectGive:
	var e := ItemEffectGive.new()
	e.give_type = ItemEffectGive.GiveType.ITEM
	e.amount = amount
	return e


func test_give_item_agrega_nueva_entrada_al_inventario() -> void:
	var effect := _make_effect(3)
	effect.apply_item(save.inventory_items, _make_item("potion"))
	assert_eq(save.inventory_items.size(), 1)
	assert_eq(save.inventory_items[0].get("id"), "potion")
	assert_eq(save.inventory_items[0].get("count"), 3)


func test_give_item_incrementa_count_de_item_existente() -> void:
	save.inventory_items.append({"id": "potion", "count": 5})
	var effect := _make_effect(4)
	effect.apply_item(save.inventory_items, _make_item("potion"))
	assert_eq(save.inventory_items.size(), 1)
	assert_eq(save.inventory_items[0].get("count"), 9)


func test_give_item_nuevo_no_supera_el_maximo() -> void:
	var effect := _make_effect(25)
	effect.apply_item(save.inventory_items, _make_item("potion"))
	assert_eq(save.inventory_items[0].get("count"), ItemEffectGive.MAX_STACK)


func test_give_item_incremento_que_supera_maximo_queda_en_maximo() -> void:
	save.inventory_items.append({"id": "potion", "count": 18})
	var effect := _make_effect(5)
	effect.apply_item(save.inventory_items, _make_item("potion"))
	assert_eq(save.inventory_items[0].get("count"), ItemEffectGive.MAX_STACK)


func test_give_item_en_maximo_no_incrementa() -> void:
	save.inventory_items.append({"id": "potion", "count": 20})
	var effect := _make_effect(10)
	effect.apply_item(save.inventory_items, _make_item("potion"))
	assert_eq(save.inventory_items[0].get("count"), ItemEffectGive.MAX_STACK)
