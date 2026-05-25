extends GutTest

var save: PlayerSaveData


func before_each() -> void:
	save = PlayerSaveData.new()


func _make_effect(key: String, val: bool) -> ItemEffectStatus:
	var e := ItemEffectStatus.new()
	e.status_key = key
	e.value = val
	return e


# ── guard ─────────────────────────────────────────────────────────────────────

func test_key_vacio_no_muta_el_save() -> void:
	var before_unlocked := save.clock_ui_unlocked
	_make_effect("", true).apply(save)
	assert_eq(save.clock_ui_unlocked, before_unlocked)


# ── path genérico (save.set) ──────────────────────────────────────────────────

func test_setea_clock_ui_unlocked_en_true() -> void:
	save.clock_ui_unlocked = false
	_make_effect("clock_ui_unlocked", true).apply(save)
	assert_true(save.clock_ui_unlocked)


func test_setea_clock_ui_unlocked_en_false() -> void:
	save.clock_ui_unlocked = true
	_make_effect("clock_ui_unlocked", false).apply(save)
	assert_false(save.clock_ui_unlocked)


func test_setea_care_ui_unlocked_en_true() -> void:
	save.care_ui_unlocked = false
	_make_effect("care_ui_unlocked", true).apply(save)
	assert_true(save.care_ui_unlocked)
