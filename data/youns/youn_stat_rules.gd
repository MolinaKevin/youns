class_name YounStatRules
extends RefCounted

## Reglas de las 8 estadísticas (YounStats.KEYS) de la partida.
##
## - PlayerSaveData.youn_stats: valor ACTUAL de cada estadística. De acá lee
##   todo el juego.
## - PlayerSaveData.youn_stat_gains: lo ganado durante esta vida (combates,
##   entrenamiento...). Solo se usa al evolucionar.
## - Al evolucionar: actual = base del nuevo Youn + lo ganado.
## - Al ganar estadísticas: se suma a la actual (y se anota como ganado); la
##   base del Youn nunca cambia.

## Valor actual de una estadística.
static func current(save: PlayerSaveData, key: String) -> int:
	return int(save.youn_stats.get(key, 0))

## Suma (o resta, con amount negativo) a la estadística actual.
static func gain(save: PlayerSaveData, key: String, amount: int) -> void:
	assert(key in YounStats.KEYS, "Estadística desconocida: %s" % key)
	save.youn_stats[key] = current(save, key) + amount
	save.youn_stat_gains[key] = int(save.youn_stat_gains.get(key, 0)) + amount

## Suma varias a la vez: {"fuerza": 20, "vitalidad": 50}.
static func gain_many(save: PlayerSaveData, amounts: Dictionary) -> void:
	for key in amounts:
		gain(save, key, int(amounts[key]))

## El Youn evoluciona: sus estadísticas base reemplazan a las actuales y se le
## suma todo lo ganado en esta vida.
static func apply_evolution(save: PlayerSaveData, new_youn: YounData) -> void:
	var base := _base_of(new_youn)
	for key in YounStats.KEYS:
		save.youn_stats[key] = int(base.get(key, 0)) + int(save.youn_stat_gains.get(key, 0))

## Vida nueva (huevo, reencarnación): arranca con la base y sin nada ganado.
static func start_life(save: PlayerSaveData, youn: YounData) -> void:
	save.youn_stat_gains.clear()
	save.youn_stats = _base_of(youn)

## Si la partida todavía no tiene estadísticas, las arranca con la base del Youn
## actual (partidas creadas antes de que existieran).
static func ensure_initialized(save: PlayerSaveData) -> void:
	if save == null or not save.youn_stats.is_empty():
		return
	if save.current_youn_path.is_empty() or not ResourceLoader.exists(save.current_youn_path):
		return
	start_life(save, load(save.current_youn_path) as YounData)

static func _base_of(youn: YounData) -> Dictionary:
	if youn == null or youn.base_stats == null:
		return YounStats.new().to_dict()
	return youn.base_stats.to_dict()
