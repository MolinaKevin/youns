extends GutTest

func test_resuelve_las_claves_del_log_en_ingles() -> void:
	var previous_language := LocalizationState.current_language
	LocalizationState.set_language("en")
	assert_eq(CombatLog.text("combat.log.enemy_card.attacks", [12]), "The enemy attacks for 12!")
	assert_eq(CombatLog.text("combat.log.grenade.hits_enemy", ["Grenade", 1.0, 2.0, 8]), "Grenade lands at (1.0,2.0) — 8 damage!")
	LocalizationState.set_language(previous_language)

func test_resuelve_las_claves_del_log_en_espanol() -> void:
	var previous_language := LocalizationState.current_language
	LocalizationState.set_language("es")
	assert_eq(CombatLog.text("combat.log.enemy_card.attacks", [12]), "¡El enemigo ataca por 12!")
	assert_eq(CombatLog.text("combat.log.grenade.hits_enemy", ["Granada", 1.0, 2.0, 8]), "¡Granada cae en (1.0,2.0) — 8 de daño!")
	LocalizationState.set_language(previous_language)
