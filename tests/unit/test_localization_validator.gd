extends GutTest

const Validator := preload("res://shared/localization_validator.gd")
const Intelligences := preload("res://data/youns/intelligences.gd")


func test_las_claves_literales_existen_en_todos_los_idiomas() -> void:
	var keys := Validator.static_keys()
	for language in LocalizationState.SUPPORTED_LANGUAGES:
		var missing := Validator.missing_keys(LocalizationState._translations[language], keys)
		assert_eq(missing, PackedStringArray(), "Claves faltantes en %s" % language)


func test_los_idiomas_tienen_el_mismo_catalogo() -> void:
	var reference: Dictionary = LocalizationState._translations[LocalizationState.DEFAULT_LANGUAGE]
	var reference_keys: Array = reference.keys()
	reference_keys.sort()
	for language in LocalizationState.SUPPORTED_LANGUAGES:
		var keys: Array = LocalizationState._translations[language].keys()
		keys.sort()
		assert_eq(keys, reference_keys)


func test_las_familias_dinamicas_existen_para_sus_catalogos() -> void:
	var card_ids: Array = CardCatalog.load_all().map(func(card: CardData) -> String: return card.id)
	var item_ids: Array = ItemCatalog.all().map(func(item: ItemData) -> String: return item.id)
	var keys := PackedStringArray()
	keys.append_array(Validator.family_keys("card.name.", card_ids))
	keys.append_array(Validator.family_keys("item.name.", item_ids))
	keys.append_array(Validator.family_keys("intelligence.", Intelligences.IDS))
	keys.append_array(Validator.family_keys("youn_stat.", YounStats.KEYS))
	keys.append_array(Validator.family_keys("combat.status_name.", CombatEffect.STATUS_FIELDS.keys()))
	keys.append_array(PackedStringArray([
		"combat.status_summary.burning", "combat.status_summary.bleeding",
		"combat.status_summary.poison", "combat.status_summary.wet",
		"combat.status_summary.greasy", "combat.status_summary.entangled",
		"combat.status_summary.frozen", "combat.status_summary.blinded",
		"combat.status_summary.block", "combat.status_summary.ward",
		"combat.status_summary.counterattack", "combat.status_summary.enchanted_weapon",
		"combat.status_summary.in_tree",
	]))
	for language in LocalizationState.SUPPORTED_LANGUAGES:
		assert_eq(Validator.missing_keys(LocalizationState._translations[language], keys), PackedStringArray(),
			"Familia dinámica incompleta en %s" % language)
