class_name EvolutionChecker

const YOUNS_DIR := "res://data/youns/"
const YounCatalogScript := preload("res://shared/youn_catalog.gd")
const REINCARNATE := "reincarnate"

## Tiempo máximo en cada etapa (días de juego). Como DW1: el bebé evoluciona a
## las 6 h y el niño al cumplir 1 día de vida.
const STAGE_MAX_DAYS := {
	"bebe": 0.25,
	"nino": 0.75,
	"adolescente": 3.0,
	"campeon": 6.0,
	"ultimate": 8.0,
}
## Condiciones cumplidas que hacen falta para llegar a un campeón o un ultimate.
const MIN_CONDITIONS := 3
const NEXT_STAGE := {
	"adolescente": "campeon",
}
## Etapas que al terminar su tiempo mueren y reencarnan.
const END_OF_LIFE_STAGES := ["campeon", "ultimate"]

## Joker temporal de niño → rookie: a dónde va si el desempate en cascada de
## _pick_by_dominant_stat() no logra distinguir a nadie. Campeón y ultimate ya
## tienen su propio Youn joker (YounData.is_wildcard); esta etapa todavía no,
## así que por ahora apunta a Newen nada más como placeholder. Cambiar esta
## constante (o reemplazarla por un YounData con is_wildcard propio una vez
## que se diseñe el joker real).
const NINO_JOKER_PATH := "res://data/youns/newen.tres"


static func try_evolve(save: PlayerSaveData, youn_data: YounData, random: RandomSource = null) -> String:
	if save == null or youn_data == null:
		return ""

	var target := check_conditions(save, youn_data, random)
	if not target.is_empty():
		return target

	var max_days: float = STAGE_MAX_DAYS.get(youn_data.stage, -1.0)
	if max_days < 0.0:
		return ""

	var days_in_stage := (GameState.get_total_hours() - save.stage_entered_total_hour) / 24.0
	if days_in_stage < max_days:
		return ""

	# Campeón o ultimate al terminar su vida: reencarna (al ultimate se llega
	# antes, en el momento de cumplir sus condiciones: check_conditions).
	if youn_data.stage in END_OF_LIFE_STAGES:
		return REINCARNATE

	if not youn_data.evolves_to.is_empty():
		return pick_target(youn_data.evolves_to, make_context(save, youn_data), random)

	# Rookie: va al campeón con MIN_CONDITIONS cumplidas (a cualquiera, como
	# DW1); si no llega a ninguno, al comodín.
	var next_stage: String = NEXT_STAGE.get(youn_data.stage, "")
	var champion := pick_by_conditions(stage_candidates(next_stage), make_context(save, youn_data), random)
	return champion if not champion.is_empty() else _find_wildcard(next_stage)


## Evolución inmediata al cumplir condiciones: un campeón pasa a uno de sus
## ultimates (evolves_to) en cuanto cumple MIN_CONDITIONS de sus condiciones.
static func check_conditions(save: PlayerSaveData, youn_data: YounData, random: RandomSource = null) -> String:
	if save == null or youn_data == null or youn_data.stage != "campeon" or youn_data.evolves_to.is_empty():
		return ""
	return pick_by_conditions(youn_data.evolves_to, make_context(save, youn_data), random)

## Entre los candidatos, el que cumple al menos MIN_CONDITIONS. Si varios: el
## de más condiciones; si empatan, el que cumple la de inteligencia; si siguen
## empatados, al azar. Vacío si ninguno llega.
static func pick_by_conditions(candidates: Array, ctx: Dictionary, random: RandomSource = null) -> String:
	var best: Array[String] = []
	var best_score := -1
	for path in candidates:
		var data := YounCatalogScript.by_path(path)
		if data == null:
			continue
		var met := count_met(data, ctx)
		if met < MIN_CONDITIONS:
			continue
		# Cumplir la inteligencia desempata (vale medio punto).
		var score := met * 2 + (1 if _meets_intelligence(data, ctx) else 0)
		if score > best_score:
			best = [path]
			best_score = score
		elif score == best_score:
			best.append(path)
	return (random.pick(best) if random != null else best.pick_random()) if not best.is_empty() else ""

static func _meets_intelligence(data: YounData, ctx: Dictionary) -> bool:
	for condition in data.evolution_conditions:
		if condition is EvolutionConditionIntelligence and condition.is_met(ctx):
			return true
	return false

## Los Youns de una etapa que no son comodín (candidatos a campeón).
static func stage_candidates(stage: String) -> Array[String]:
	var result: Array[String] = []
	if stage.is_empty():
		return result
	return YounCatalogScript.paths_for_stage(stage, false)


static func make_context(save: PlayerSaveData, from: YounData) -> Dictionary:
	return {
		"save": save,
		"from": from,
		"hour": GameState.time_of_day_hours,
		"zone": ZoneManager.current_zone,
	}


## Elige entre los candidatos (el primero es el de por defecto):
## - Si tienen dominant_stats (niño → rookie): va al dueño de la stat más alta.
## - Si no: gana el que cumple más condiciones.
## Si nadie gana o hay empate, va el de por defecto.
static func pick_target(candidates: Array[String], ctx: Dictionary, _random: RandomSource = null) -> String:
	if candidates.is_empty():
		return ""
	var datas: Array[YounData] = []
	for path in candidates:
		datas.append(YounCatalogScript.by_path(path))
	if datas.any(func(d: YounData) -> bool: return d != null and not d.dominant_stats.is_empty()):
		return _pick_by_dominant_stat(candidates, datas, ctx)
	var best := candidates[0]
	var best_score := 0
	var tied := false
	for i in candidates.size():
		var path := candidates[i]
		var score := count_met(datas[i], ctx)
		if score > best_score:
			best = path
			best_score = score
			tied = false
		elif score == best_score and score > 0:
			tied = true
	if best_score == 0 or tied:
		return candidates[0]
	return best


## Va al candidato dueño de la stat más alta. Si varios empatan arriba,
## desempata con la stat siguiente en el ranking (y la que sigue, y así) entre
## los candidatos todavía en pie. Si se llega al final sin que ninguno se
## distinga, va al joker (NINO_JOKER_PATH).
static func _pick_by_dominant_stat(candidates: Array[String], datas: Array[YounData], ctx: Dictionary) -> String:
	var save: PlayerSaveData = ctx.get("save")
	if save == null:
		return _nino_joker_or_default(candidates)
	var contenders: Array[int] = []
	for i in datas.size():
		contenders.append(i)
	for tier in _stats_ranked_desc(save.youn_stats):
		var owners: Array[int] = []
		for key in tier:
			for i in contenders:
				if datas[i] != null and key in datas[i].dominant_stats and not i in owners:
					owners.append(i)
		if owners.size() == 1:
			return candidates[owners[0]]
		if owners.size() > 1:
			contenders = owners
	return _nino_joker_or_default(candidates)


## El joker si está entre los candidatos de este niño; si no (otro niño cuyo
## evolves_to no lo incluya), el primero de la lista como red de seguridad.
static func _nino_joker_or_default(candidates: Array[String]) -> String:
	return NINO_JOKER_PATH if NINO_JOKER_PATH in candidates else candidates[0]


## Las stats con el valor más alto (varias si empatan).
static func dominant_stats(stats: Dictionary) -> Array[String]:
	var tiers := _stats_ranked_desc(stats)
	return tiers[0] if not tiers.is_empty() else []


## Las 8 stats agrupadas por valor, de mayor a menor (cada grupo = las que
## empatan entre sí en ese escalón). Lo usan dominant_stats() (solo el primer
## escalón) y _pick_by_dominant_stat() (todos, para desempatar en cascada).
static func _stats_ranked_desc(stats: Dictionary) -> Array:
	var by_value := {}
	for key in YounStats.KEYS:
		var value := float(stats.get(key, 0))
		if not by_value.has(value):
			by_value[value] = [] as Array[String]
		by_value[value].append(key)
	var values := by_value.keys()
	values.sort()
	values.reverse()
	var tiers := []
	for value in values:
		tiers.append(by_value[value])
	return tiers


## Cuántas condiciones de evolución de target se cumplen.
static func count_met(target: YounData, ctx: Dictionary) -> int:
	if target == null:
		return 0
	var met := 0
	for condition in target.evolution_conditions:
		if condition != null and condition.is_met(ctx):
			met += 1
	return met


static func _find_wildcard(stage: String) -> String:
	if stage.is_empty():
		return ""
	var paths := YounCatalogScript.paths_for_stage(stage, true)
	if not paths.is_empty():
		return paths[0]
	return ""
