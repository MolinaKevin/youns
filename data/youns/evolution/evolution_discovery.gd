class_name EvolutionDiscovery
extends RefCounted

## Revelación progresiva de las condiciones de evolución:
## - La primera vez que se evoluciona A un Youn se desbloquea (aparece en el
##   árbol de evoluciones). Si se cumplió la condición de inteligencia, se
##   revela esa; si no, ninguna.
## - Desde la segunda vez, cada evolución revela siempre una condición: primero
##   alguna de las cumplidas que no se conocía (la de inteligencia antes que las
##   demás) y, si no queda ninguna, una de las no cumplidas. Así siempre se
##   avanza, aunque haya condiciones muy difíciles de cumplir.
## Los niños ("evolucionar desde X") y los rookies ("X como stat dominante")
## tienen su propia regla: siempre se revela la condición cumplida, también la
## primera vez, y nunca una no cumplida. Si la cumplida ya se conocía, no se
## revela nada nuevo.
## Lo descubierto queda en PlayerSaveData.discovered_evolutions.

## Etapas con la regla de "siempre y solo la cumplida".
const ONLY_MET_STAGES := ["nino", "adolescente"]

## Índices (en target.evolution_conditions) de las condiciones que se cumplen.
static func met_indices(target: YounData, ctx: Dictionary) -> Array[int]:
	var result: Array[int] = []
	if target == null:
		return result
	for i in target.evolution_conditions.size():
		var condition: EvolutionCondition = target.evolution_conditions[i]
		if condition != null and condition.is_met(ctx):
			result.append(i)
	return result

## Registra que se evolucionó a `target` (con `met` = condiciones cumplidas) y
## revela la condición que corresponda. Devuelve:
## {"first_time": bool, "revealed": índice o -1, "revealed_met": bool
##  (si la revelada se había cumplido), "known": [índices conocidos]}.
static func discover(save: PlayerSaveData, target: YounData, met: Array[int]) -> Dictionary:
	var result := {"first_time": false, "revealed": -1, "revealed_met": false, "known": []}
	if save == null or target == null:
		return result
	var key := youn_key(target)
	var first_time := not save.discovered_evolutions.has(key)
	result["first_time"] = first_time
	var known: Array = save.discovered_evolutions.get(key, []).duplicate()
	var met_unknown: Array = []
	var unmet_unknown: Array = []
	for i in target.evolution_conditions.size():
		if known.has(i) or target.evolution_conditions[i] == null:
			continue
		if met.has(i):
			met_unknown.append(i)
		else:
			unmet_unknown.append(i)
	var revealed := -1
	if target.stage in ONLY_MET_STAGES:
		# Niños y rookies: solo la cumplida (una sola si empatan), siempre.
		if not met_unknown.is_empty():
			revealed = met_unknown.pick_random()
	elif first_time:
		# La primera vez solo se revela la inteligencia, y solo si se cumplió.
		revealed = _intelligence_in(target, met_unknown)
	elif not met_unknown.is_empty():
		revealed = _pick(target, met_unknown)
	elif not unmet_unknown.is_empty():
		revealed = _pick(target, unmet_unknown)
	if revealed >= 0:
		known.append(revealed)
		result["revealed"] = revealed
		result["revealed_met"] = met.has(revealed)
	save.discovered_evolutions[key] = known
	result["known"] = known.duplicate()
	return result

## La de inteligencia si está entre las candidatas; si no, una al azar.
static func _pick(target: YounData, candidates: Array) -> int:
	var intelligence := _intelligence_in(target, candidates)
	return intelligence if intelligence >= 0 else candidates.pick_random()

static func _intelligence_in(target: YounData, candidates: Array) -> int:
	for i in candidates:
		if target.evolution_conditions[i] is EvolutionConditionIntelligence:
			return i
	return -1

static func youn_key(data: YounData) -> String:
	return data.id if not data.id.is_empty() else data.resource_path
