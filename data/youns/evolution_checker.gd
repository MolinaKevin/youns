class_name EvolutionChecker

const YOUNS_DIR := "res://data/youns/"
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


static func try_evolve(save: PlayerSaveData, youn_data: YounData) -> String:
	if save == null or youn_data == null:
		return ""

	var target := check_conditions(save, youn_data)
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
		return pick_target(youn_data.evolves_to, make_context(save, youn_data))

	# Rookie: va al campeón con MIN_CONDITIONS cumplidas (a cualquiera, como
	# DW1); si no llega a ninguno, al comodín.
	var next_stage: String = NEXT_STAGE.get(youn_data.stage, "")
	var champion := pick_by_conditions(stage_candidates(next_stage), make_context(save, youn_data))
	return champion if not champion.is_empty() else _find_wildcard(next_stage)


## Evolución inmediata al cumplir condiciones: un campeón pasa a uno de sus
## ultimates (evolves_to) en cuanto cumple MIN_CONDITIONS de sus condiciones.
static func check_conditions(save: PlayerSaveData, youn_data: YounData) -> String:
	if save == null or youn_data == null or youn_data.stage != "campeon" or youn_data.evolves_to.is_empty():
		return ""
	return pick_by_conditions(youn_data.evolves_to, make_context(save, youn_data))

## Entre los candidatos, el que cumple al menos MIN_CONDITIONS. Si varios: el
## de más condiciones; si empatan, el que cumple la de inteligencia; si siguen
## empatados, al azar. Vacío si ninguno llega.
static func pick_by_conditions(candidates: Array, ctx: Dictionary) -> String:
	var best: Array[String] = []
	var best_score := -1
	for path in candidates:
		var data := load(path) as YounData
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
	return best.pick_random() if not best.is_empty() else ""

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
	var dir := DirAccess.open(YOUNS_DIR)
	if dir == null:
		return result
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var data := load(YOUNS_DIR + file) as YounData
		if data != null and data.stage == stage and not data.is_wildcard:
			result.append(YOUNS_DIR + file)
	return result


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
static func pick_target(candidates: Array[String], ctx: Dictionary) -> String:
	if candidates.is_empty():
		return ""
	var datas: Array[YounData] = []
	for path in candidates:
		datas.append(load(path) as YounData)
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


## Va al candidato dueño de la stat más alta. Si varias empatan arriba y son
## de distintos candidatos (o de ninguno), va el de por defecto.
static func _pick_by_dominant_stat(candidates: Array[String], datas: Array[YounData], ctx: Dictionary) -> String:
	var save: PlayerSaveData = ctx.get("save")
	if save == null:
		return candidates[0]
	var winner := -1
	for key in dominant_stats(save.youn_stats):
		var owner := -1
		for i in datas.size():
			if datas[i] != null and key in datas[i].dominant_stats:
				owner = i
				break
		if owner < 0 or (winner >= 0 and owner != winner):
			return candidates[0]
		winner = owner
	return candidates[maxi(winner, 0)]


## Las stats con el valor más alto (varias si empatan).
static func dominant_stats(stats: Dictionary) -> Array[String]:
	var best: Array[String] = []
	var best_value := -INF
	for key in YounStats.KEYS:
		var value := float(stats.get(key, 0))
		if value > best_value:
			best = [key]
			best_value = value
		elif value == best_value:
			best.append(key)
	return best


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
	var dir := DirAccess.open(YOUNS_DIR)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var data := load(YOUNS_DIR + file) as YounData
			if data and data.stage == stage and data.is_wildcard:
				return YOUNS_DIR + file
		file = dir.get_next()
	return ""
