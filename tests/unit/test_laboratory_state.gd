extends GutTest

# Testea la lógica pura del LaboratoryState: inventario pending_output,
# ingredientes, rewards tipo "item", output y desbloqueos.
# Los paths que tocan GlobalHUD (unlock_clock_ui / unlock_care_ui) se omiten.

var _previous_save: PlayerSaveData
var _previous_pending_output: Dictionary
var _previous_unlocked_columns: Array
var _previous_all_recipes: Array[Resource]
var _previous_recipes_by_ingredient: Dictionary
var _previous_active_recipe_id := ""
var _previous_recipe_progress: Dictionary


func before_each() -> void:
	_previous_save = GameState.player_save
	_previous_pending_output = LaboratoryState.pending_output.duplicate(true)
	_previous_unlocked_columns = LaboratoryState.unlocked_columns.duplicate(true)
	_previous_all_recipes = LaboratoryState.all_recipes.duplicate()
	_previous_recipes_by_ingredient = LaboratoryState.recipes_by_ingredient.duplicate(true)
	_previous_active_recipe_id = LaboratoryState.active_recipe_id
	_previous_recipe_progress = LaboratoryState.recipe_progress.duplicate(true)
	GameState.player_save = PlayerSaveData.new()
	LaboratoryState.pending_output = {}
	LaboratoryState.unlocked_columns = []
	LaboratoryState.all_recipes = []
	LaboratoryState.recipes_by_ingredient = {}
	LaboratoryState.active_recipe_id = ""
	LaboratoryState.recipe_progress = {}


func after_each() -> void:
	GameState.player_save = _previous_save
	LaboratoryState.pending_output = _previous_pending_output.duplicate(true)
	LaboratoryState.unlocked_columns = _previous_unlocked_columns.duplicate(true)
	LaboratoryState.all_recipes = _previous_all_recipes.duplicate()
	LaboratoryState.recipes_by_ingredient = _previous_recipes_by_ingredient.duplicate(true)
	LaboratoryState.active_recipe_id = _previous_active_recipe_id
	LaboratoryState.recipe_progress = _previous_recipe_progress.duplicate(true)


func _make_recipe(id: String, gold: int, ingredients: Array) -> LabRecipe:
	var r := LabRecipe.new()
	r.id = id
	r.recipe_name = id
	r.item_name = id
	r.gold_cost = gold
	for ing in ingredients:
		r.ingredients.append(ing)
	r.needs_research = false
	r.action_type = "loop"
	r.location = "lab"
	return r


func _put_item(item_id: String, count: int) -> void:
	LaboratoryState.pending_output[item_id] = {"id": item_id, "name": item_id, "count": count}


# ── has_ingredients ───────────────────────────────────────────────────────────

func test_has_ingredients_sin_ingredientes_ni_costo_retorna_true() -> void:
	var recipe := _make_recipe("r", 0, [])
	assert_true(LaboratoryState.has_ingredients(recipe))


func test_has_ingredients_con_item_suficiente_retorna_true() -> void:
	_put_item("wood", 5)
	var recipe := _make_recipe("r", 0, [{"id": "wood", "amount": 3}])
	assert_true(LaboratoryState.has_ingredients(recipe))


func test_has_ingredients_item_no_disponible_retorna_false() -> void:
	var recipe := _make_recipe("r", 0, [{"id": "wood", "amount": 1}])
	assert_false(LaboratoryState.has_ingredients(recipe))


func test_has_ingredients_count_insuficiente_retorna_false() -> void:
	_put_item("wood", 2)
	var recipe := _make_recipe("r", 0, [{"id": "wood", "amount": 5}])
	assert_false(LaboratoryState.has_ingredients(recipe))


func test_has_ingredients_gold_insuficiente_retorna_false() -> void:
	GameState.player_save.gold = 10
	var recipe := _make_recipe("r", 50, [])
	assert_false(LaboratoryState.has_ingredients(recipe))


func test_has_ingredients_items_del_inventario_del_jugador_no_cuentan() -> void:
	# El inventario del jugador no es el inventario del lab — no debe satisfacer ingredientes
	GameState.player_save.inventory_items.append({"id": "wood", "count": 10})
	var recipe := _make_recipe("r", 0, [{"id": "wood", "amount": 1}])
	assert_false(LaboratoryState.has_ingredients(recipe))


func test_has_ingredients_gold_suficiente_retorna_true() -> void:
	GameState.player_save.gold = 100
	var recipe := _make_recipe("r", 50, [])
	assert_true(LaboratoryState.has_ingredients(recipe))


# ── _consume_ingredients ──────────────────────────────────────────────────────

func test_consume_reduce_count_del_item() -> void:
	_put_item("wood", 5)
	var recipe := _make_recipe("r", 0, [{"id": "wood", "amount": 2}])
	LaboratoryState.consume_ingredients(recipe)
	assert_eq(LaboratoryState.pending_output["wood"]["count"], 3)


func test_consume_elimina_entrada_cuando_count_llega_a_cero() -> void:
	_put_item("wood", 2)
	var recipe := _make_recipe("r", 0, [{"id": "wood", "amount": 2}])
	LaboratoryState.consume_ingredients(recipe)
	assert_false(LaboratoryState.pending_output.has("wood"))


func test_consume_deduce_gold_del_save() -> void:
	GameState.player_save.gold = 100
	var recipe := _make_recipe("r", 30, [])
	LaboratoryState.consume_ingredients(recipe)
	assert_eq(GameState.player_save.gold, 70)


# ── _process_reward — item ────────────────────────────────────────────────────

func test_reward_item_agrega_nuevo_item_a_pending_output() -> void:
	LaboratoryState.grant_reward({"type": "item", "id": "potion", "amount": 3}, "r")
	assert_eq(LaboratoryState.pending_output["potion"]["count"], 3)


func test_reward_item_acumula_sobre_item_existente() -> void:
	_put_item("potion", 5)
	LaboratoryState.grant_reward({"type": "item", "id": "potion", "amount": 4}, "r")
	assert_eq(LaboratoryState.pending_output["potion"]["count"], 9)


func test_reward_item_no_supera_99() -> void:
	_put_item("potion", 97)
	LaboratoryState.grant_reward({"type": "item", "id": "potion", "amount": 5}, "r")
	assert_eq(LaboratoryState.pending_output["potion"]["count"], 99)


func test_reward_item_en_99_no_incrementa() -> void:
	_put_item("potion", 99)
	LaboratoryState.grant_reward({"type": "item", "id": "potion", "amount": 1}, "r")
	assert_eq(LaboratoryState.pending_output["potion"]["count"], 99)


func test_reward_world_bridge_guarda_el_puente_en_el_progreso() -> void:
	LaboratoryState.grant_reward({"type": "world_bridge", "id": "river_bridge"}, "r")

	assert_true(GameState.player_save.world_progress.has_bridge("river_bridge"))


func test_reward_youn_growth_bonus_se_acumula() -> void:
	LaboratoryState.grant_reward({"type": "youn_growth_bonus", "value": 2}, "r")
	LaboratoryState.grant_reward({"type": "youn_growth_bonus", "value": 1}, "r")

	assert_eq(GameState.player_save.lab_youn_growth_bonus, 3)


func test_reward_material_production_agrega_datos_al_deposito() -> void:
	LaboratoryState.grant_reward({"type": "material_production", "value": 3}, "r")

	assert_eq(LaboratoryState.pending_output["datos"]["count"], 3)


func test_reward_max_hp_se_acumula() -> void:
	LaboratoryState.grant_reward({"type": "max_hp", "value": 25}, "r")
	LaboratoryState.grant_reward({"type": "max_hp", "value": 10}, "r")

	assert_eq(GameState.player_save.lab_max_hp_bonus, 35)


# ── Ecos de cartas ───────────────────────────────────────────────────────────
# El conteo por carta (qué Ecos da) es puro (LaboratoryEchoes.echo_ids_for_card);
# combate es quien lo va acumulando y acá solo se prueba el acreditado final.

func test_echo_ids_for_card_una_por_inteligencia() -> void:
	var card := CardData.new()
	card.top = CardAction.new()
	card.top.intelligence = "logica"
	card.bottom = CardAction.new()
	card.bottom.intelligence = "musical"
	var ids := LaboratoryEchoes.echo_ids_for_card(card)
	assert_true(ids.has("eco_logica"))
	assert_true(ids.has("eco_musical"))
	assert_eq(ids.size(), 2)


func test_echo_ids_for_card_misma_inteligencia_da_un_solo_id() -> void:
	var card := CardData.new()
	card.top = CardAction.new()
	card.top.intelligence = "espacial"
	card.bottom = CardAction.new()
	card.bottom.intelligence = "espacial"
	var ids := LaboratoryEchoes.echo_ids_for_card(card)
	assert_eq(ids, ["eco_espacial"] as Array[String])


func test_deposit_echoes_acredita_lo_juntado_en_el_combate() -> void:
	LaboratoryState.deposit_echoes({"eco_logica": 3, "eco_musical": 1})
	assert_eq(LaboratoryState.pending_output["eco_logica"]["count"], 3)
	assert_eq(LaboratoryState.pending_output["eco_musical"]["count"], 1)


func test_deposit_echoes_pueden_acumular_mas_de_99() -> void:
	_put_item("eco_logica", 99)
	LaboratoryState.deposit_echoes({"eco_logica": 2})
	assert_eq(LaboratoryState.pending_output["eco_logica"]["count"], 101)


# ── take_all_output ───────────────────────────────────────────────────────────

func test_take_all_output_retorna_los_items() -> void:
	_put_item("potion", 3)
	_put_item("wood", 7)
	var result := LaboratoryState.take_all_output()
	assert_eq(result["potion"]["count"], 3)
	assert_eq(result["wood"]["count"], 7)


func test_take_all_output_vacia_el_pending_output() -> void:
	_put_item("potion", 3)
	LaboratoryState.take_all_output()
	assert_true(LaboratoryState.pending_output.is_empty())


func test_restore_output_devuelve_al_deposito_lo_que_no_entra_al_inventario() -> void:
	LaboratoryState.restore_output({"wood": {"id": "wood", "name": "wood", "count": 3}})

	assert_eq(LaboratoryState.pending_output["wood"]["count"], 3)


# ── desbloqueo de recetas ─────────────────────────────────────────────────────

func test_is_recipe_unlocked_false_inicialmente() -> void:
	assert_false(LaboratoryState.is_recipe_unlocked("r"))


func test_unlock_recipe_marca_como_desbloqueada() -> void:
	LaboratoryState.all_recipes.append(_make_recipe("r", 0, []))
	LaboratoryState.unlock_recipe("r")
	assert_true(LaboratoryState.is_recipe_unlocked("r"))


func test_unlock_recipe_no_duplica() -> void:
	LaboratoryState.all_recipes.append(_make_recipe("r", 0, []))
	LaboratoryState.unlock_recipe("r")
	LaboratoryState.unlock_recipe("r")
	var count := GameState.player_save.unlocked_recipe_ids.filter(func(id): return id == "r").size()
	assert_eq(count, 1)


func test_is_recipe_completed_false_inicialmente() -> void:
	assert_false(LaboratoryState.is_recipe_completed("r"))


func test_complete_recipe_marca_como_completada() -> void:
	LaboratoryState.complete_recipe("r")
	assert_true(LaboratoryState.is_recipe_completed("r"))


# ── _check_indirect_unlocks ───────────────────────────────────────────────────

func test_check_indirect_unlocks_desbloquea_cuando_hay_ingredientes() -> void:
	var recipe := _make_recipe("advanced", 0, [{"id": "wood", "amount": 2}])
	LaboratoryState.all_recipes.append(recipe)
	LaboratoryState.recipes_by_ingredient["wood"] = [recipe]
	_put_item("wood", 3)

	LaboratoryState.check_indirect_unlocks("wood")

	assert_true(LaboratoryState.is_recipe_unlocked("advanced"))


func test_check_indirect_unlocks_no_desbloquea_si_faltan_ingredientes() -> void:
	var recipe := _make_recipe("advanced", 0, [{"id": "wood", "amount": 5}])
	LaboratoryState.all_recipes.append(recipe)
	LaboratoryState.recipes_by_ingredient["wood"] = [recipe]
	_put_item("wood", 2)

	LaboratoryState.check_indirect_unlocks("wood")

	assert_false(LaboratoryState.is_recipe_unlocked("advanced"))


func test_check_indirect_unlocks_no_desbloquea_si_needs_research() -> void:
	var recipe := _make_recipe("advanced", 0, [{"id": "wood", "amount": 1}])
	recipe.needs_research = true
	LaboratoryState.all_recipes.append(recipe)
	LaboratoryState.recipes_by_ingredient["wood"] = [recipe]
	_put_item("wood", 5)

	LaboratoryState.check_indirect_unlocks("wood")

	assert_false(LaboratoryState.is_recipe_unlocked("advanced"))


func test_check_indirect_unlocks_no_desbloquea_si_ya_esta_desbloqueada() -> void:
	var recipe := _make_recipe("advanced", 0, [{"id": "wood", "amount": 1}])
	LaboratoryState.all_recipes.append(recipe)
	LaboratoryState.recipes_by_ingredient["wood"] = [recipe]
	_put_item("wood", 5)
	LaboratoryState.unlock_recipe("advanced")  # ya desbloqueada

	# reset save para que unlock_recipe no duplique pero is_recipe_unlocked siga true
	LaboratoryState.check_indirect_unlocks("wood")

	var count := GameState.player_save.unlocked_recipe_ids.filter(func(id): return id == "advanced").size()
	assert_eq(count, 1)
