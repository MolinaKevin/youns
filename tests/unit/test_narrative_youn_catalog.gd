extends GutTest

const NarrativeYouns := preload("res://data/youns/narrative_youn_catalog.gd")


func test_los_youns_narrativos_apuntan_a_recursos_validos() -> void:
	for path in [NarrativeYouns.PACHAMAMA, NarrativeYouns.NEWEN, NarrativeYouns.NGURUVILU]:
		assert_is(load(path), YounData, "Recurso narrativo inválido: %s" % path)
	for path in NarrativeYouns.WELCOME_GUESTS:
		assert_is(load(path), YounData, "Invitado narrativo inválido: %s" % path)
	assert_not_null(NarrativeYouns.pachamama())
	assert_eq(NarrativeYouns.welcome_guests().size(), NarrativeYouns.WELCOME_GUESTS.size())


func test_las_claves_de_la_ceremonia_existen_en_todos_los_idiomas() -> void:
	var keys := [
		"ceremony.greeting", "ceremony.player_question", "ceremony.player_placeholder",
		"ceremony.path_question", "ceremony.path_forest", "ceremony.path_lake",
		"ceremony.social_question", "ceremony.social_people", "ceremony.social_solitude",
		"ceremony.companion_question", "ceremony.companion_placeholder",
		"ceremony.choice_confirmed", "ceremony.keyboard_hint", "ceremony.name_required",
		"ceremony.key_upper", "ceremony.key_lower", "ceremony.key_space",
		"ceremony.key_delete", "ceremony.key_done",
		"welcome.player_fallback", "welcome.companion_fallback", "welcome.look_around",
		"welcome.every_youn", "welcome.introduce_companion", "welcome.care_together",
	]
	for language in LocalizationState.SUPPORTED_LANGUAGES:
		var translations: Dictionary = LocalizationState._translations[language]
		for key in keys:
			assert_true(translations.has(key), "Falta %s en %s" % [key, language])
