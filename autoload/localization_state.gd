extends Node

signal language_changed(language: String)

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "general"
const SETTINGS_KEY_LANGUAGE := "language"
const TRANSLATIONS_DIR := "res://data/localization/"

const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["es", "en"]

var current_language := DEFAULT_LANGUAGE
var _has_saved_language := false
var _translations: Dictionary = {}

func _ready() -> void:
	_load_all_translations()
	_load_language()

func has_saved_language() -> bool:
	return _has_saved_language

func get_language_name(language: String = current_language) -> String:
	return t("language.%s" % language)

func location_name(location_id: String) -> String:
	return t("lab.location.%s" % location_id)

func action_type_name(action_type: String) -> String:
	return t("lab.action.%s" % action_type)

func card_name(card_id: String, fallback: String = "") -> String:
	return t("card.name.%s" % card_id) if has_key("card.name.%s" % card_id) else fallback

func card_description(card_id: String, fallback: String = "") -> String:
	return t("card.desc.%s" % card_id) if has_key("card.desc.%s" % card_id) else fallback

func card_type_name(card_type: String) -> String:
	return t("card_type.%s" % card_type) if has_key("card_type.%s" % card_type) else card_type

func recipe_name(recipe_id: String, fallback: String = "") -> String:
	return t("recipe.name.%s" % recipe_id) if has_key("recipe.name.%s" % recipe_id) else fallback

func recipe_description(recipe_id: String, fallback: String = "") -> String:
	return t("recipe.desc.%s" % recipe_id) if has_key("recipe.desc.%s" % recipe_id) else fallback

func item_name(item_id: String, fallback: String = "") -> String:
	return t("item.name.%s" % item_id) if has_key("item.name.%s" % item_id) else fallback

func enemy_name(enemy_id: String, fallback: String = "") -> String:
	return t("enemy.name.%s" % enemy_id) if has_key("enemy.name.%s" % enemy_id) else fallback

func t(key: String, args: Array = []) -> String:
	var text: String = _get_text_for_key(key)
	return text % args if not args.is_empty() else text

func has_key(key: String) -> bool:
	var current_table: Dictionary = _translations.get(current_language, {})
	var fallback_table: Dictionary = _translations.get(DEFAULT_LANGUAGE, {})
	return current_table.has(key) or fallback_table.has(key)

func set_language(language: String) -> void:
	if language not in SUPPORTED_LANGUAGES:
		return
	current_language = language
	_has_saved_language = true
	_save_language()
	language_changed.emit(language)

func _load_all_translations() -> void:
	_translations.clear()
	for language in SUPPORTED_LANGUAGES:
		_translations[language] = _load_translation_file(language)

func _load_translation_file(language: String) -> Dictionary:
	var path := "%s%s.json" % [TRANSLATIONS_DIR, language]
	if not FileAccess.file_exists(path):
		push_warning("LocalizationState: missing translation file %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("LocalizationState: failed to open translation file %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LocalizationState: invalid translation json %s" % path)
		return {}

	return parsed

func _get_text_for_key(key: String) -> String:
	var current_table: Dictionary = _translations.get(current_language, {})
	var fallback_table: Dictionary = _translations.get(DEFAULT_LANGUAGE, {})
	return str(current_table.get(key, fallback_table.get(key, key)))

func _load_language() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_language := str(config.get_value(SETTINGS_SECTION, SETTINGS_KEY_LANGUAGE, DEFAULT_LANGUAGE))
		if saved_language in SUPPORTED_LANGUAGES:
			current_language = saved_language
			_has_saved_language = true

func _save_language() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY_LANGUAGE, current_language)
	config.save(SETTINGS_PATH)
