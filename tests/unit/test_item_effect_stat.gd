extends GutTest

var save: PlayerSaveData
var _youn_backup: Node


func before_each() -> void:
	save = PlayerSaveData.new()
	GameState.player_save = save
	_youn_backup = PartyManager.youn
	PartyManager.youn = null


func after_each() -> void:
	GameState.player_save = null
	PartyManager.youn = _youn_backup


func _make_stat_effect(key: String, delta: float) -> ItemEffectStat:
	var e := ItemEffectStat.new()
	e.stat_key = key
	e.delta = delta
	return e


func _make_set_effect(key: String, value: float) -> ItemEffectSetStat:
	var e := ItemEffectSetStat.new()
	e.stat_key = key
	e.value = value
	return e


# ── ItemEffectStat ────────────────────────────────────────────────────────────

func test_stat_sube_la_stat() -> void:
	save.salud = 50
	_make_stat_effect("salud", 30.0).apply(save)
	assert_eq(save.salud, 80)


func test_stat_baja_la_stat() -> void:
	save.estres = 60
	_make_stat_effect("estres", -20.0).apply(save)
	assert_eq(save.estres, 40)


func test_stat_clamp_maximo_100() -> void:
	save.felicidad = 90
	_make_stat_effect("felicidad", 20.0).apply(save)
	assert_eq(save.felicidad, 100)


func test_stat_clamp_minimo_0() -> void:
	save.energia = 10
	_make_stat_effect("energia", -50.0).apply(save)
	assert_eq(save.energia, 0)


func test_stat_guard_key_vacia_no_modifica_nada() -> void:
	save.salud = 70
	_make_stat_effect("", 30.0).apply(save)
	assert_eq(save.salud, 70)


func test_stat_key_inexistente_no_crashea() -> void:
	save.salud = 70
	_make_stat_effect("no_existe", 10.0).apply(save)
	assert_eq(save.salud, 70)


# ── ItemEffectSetStat ─────────────────────────────────────────────────────────

func test_set_stat_pone_el_valor_exacto() -> void:
	save.energia = 20
	_make_set_effect("energia", 100.0).apply(save)
	assert_eq(save.energia, 100)


func test_set_stat_puede_bajar_la_stat() -> void:
	save.hambre = 80
	_make_set_effect("hambre", 0.0).apply(save)
	assert_eq(save.hambre, 0)


func test_set_stat_clamp_maximo_100() -> void:
	save.salud = 50
	_make_set_effect("salud", 150.0).apply(save)
	assert_eq(save.salud, 100)


func test_set_stat_clamp_minimo_0() -> void:
	save.estres = 50
	_make_set_effect("estres", -10.0).apply(save)
	assert_eq(save.estres, 0)


func test_set_stat_guard_key_vacia_no_modifica_nada() -> void:
	save.salud = 70
	_make_set_effect("", 100.0).apply(save)
	assert_eq(save.salud, 70)


func test_set_stat_key_inexistente_no_crashea() -> void:
	save.salud = 70
	_make_set_effect("no_existe", 50.0).apply(save)
	assert_eq(save.salud, 70)
