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

## Vida máxima: sale de la constitución.
const HP_PER_CONSTITUCION := 4
## Si no hay estadísticas (p. ej. combate abierto directo desde el editor).
const DEFAULT_MAX_HP := 400

## MP máximo: sale de la mente.
const MP_PER_MENTE := 2

## Cuánto puede adelantar o atrasar la iniciativa de su carta según la
## agilidad: [agilidad, margen], interpolando entre puntos (y siguiendo la
## última pendiente por encima de 100).
const INITIATIVE_SHIFT_POINTS := [[0, 0], [50, 3], [75, 6], [100, 10]]

## Resistencia a estados: cada tantos puntos por encima de 50 los estados
## duran un turno menos (y por debajo de 50, uno más).
const RESISTENCIA_PER_STATUS_TURN := 25

## Estadísticas que cambiaron de nombre: clave vieja → nueva.
const RENAMED_KEYS := {"vitalidad": "constitucion", "energia": "mente"}

## Vida máxima para esas estadísticas ({"constitucion": 50, ...}).
static func max_hp(stats: Dictionary) -> int:
	if not stats.has("constitucion"):
		return DEFAULT_MAX_HP
	return maxi(1, int(stats["constitucion"]) * HP_PER_CONSTITUCION)

## MP máximo para esas estadísticas ({"mente": 50, ...}).
static func max_mp(stats: Dictionary) -> int:
	return maxi(0, int(stats.get("mente", 0)) * MP_PER_MENTE)

## Margen de iniciativa (±) para esas estadísticas: 50 → 3, 75 → 6, 100 → 10.
static func initiative_shift(stats: Dictionary) -> int:
	var agilidad := float(stats.get("agilidad", 0))
	var pts: Array = INITIATIVE_SHIFT_POINTS
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if agilidad <= b[0]:
			var t: float = (agilidad - a[0]) / float(b[0] - a[0])
			return maxi(0, floori(lerpf(a[1], b[1], t)))
	var last: Array = pts[pts.size() - 1]
	var prev: Array = pts[pts.size() - 2]
	var slope: float = float(last[1] - prev[1]) / float(last[0] - prev[0])
	return floori(last[1] + (agilidad - last[0]) * slope)

## Turnos que se le restan a los estados: 50 → 0, 75 → 1, 100 → 2, 25 → -1.
static func status_reduction(stats: Dictionary) -> int:
	if not stats.has("resistencia"):
		return 0
	return floori((float(stats["resistencia"]) - 50.0) / RESISTENCIA_PER_STATUS_TURN)

## Valor actual de una estadística.
static func current(save: PlayerSaveData, key: String) -> int:
	return int(save.youn_stats.get(key, 0))

## Suma (o resta, con amount negativo) a la estadística actual.
static func gain(save: PlayerSaveData, key: String, amount: int) -> void:
	assert(key in YounStats.KEYS, "Estadística desconocida: %s" % key)
	save.youn_stats[key] = current(save, key) + amount
	save.youn_stat_gains[key] = int(save.youn_stat_gains.get(key, 0)) + amount

## Suma varias a la vez: {"fuerza": 20, "constitucion": 50}.
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

## Pasa las claves viejas de la partida a su nombre nuevo (RENAMED_KEYS).
static func migrate_keys(save: PlayerSaveData) -> void:
	if save == null:
		return
	for dict in [save.youn_stats, save.youn_stat_gains]:
		for old_key in RENAMED_KEYS:
			if dict.has(old_key):
				var new_key: String = RENAMED_KEYS[old_key]
				dict[new_key] = int(dict.get(new_key, 0)) + int(dict[old_key])
				dict.erase(old_key)

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
