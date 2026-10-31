class_name EmotionService
extends RefCounted

## Reglas y ciclo de vida de emociones. Recibe callbacks para las consecuencias
## de cuidado (penalidades y accidente) sin poseer las stats ni las cinemáticas.

const RULES_DIR := "res://data/emotions/rules/"

var active_states: Dictionary = {}
var _rules: Array[EmotionRule] = []
var _block_count := 0
var _session: CareSessionContext
var _apply_expire_penalty: Callable
var _apply_bathroom_accident: Callable
var _queue_stat_changed: Callable
var _random: RandomSource


func _init(session: CareSessionContext, expire_penalty: Callable, bathroom_accident: Callable, stat_changed: Callable, random: RandomSource = null) -> void:
	_session = session
	_apply_expire_penalty = expire_penalty
	_apply_bathroom_accident = bathroom_accident
	_queue_stat_changed = stat_changed
	_random = random if random != null else RandomSource.new()
	_rules = _load_rules()


func is_blocked() -> bool:
	return _block_count > 0


## Consultas de sólo lectura para UI, mundo y guardado. Mantienen las claves
## serializadas dentro de este servicio en vez de exponerlas a cada consumidor.
func has_state(emotion_name: String) -> bool:
	return emotion_name in active_states


func state_entry(emotion_name: String) -> Dictionary:
	return active_states.get(emotion_name, {}).duplicate(true)


func active_state_names() -> PackedStringArray:
	var names := PackedStringArray()
	for emotion_name in active_states:
		names.append(str(emotion_name))
	return names


func active_states_snapshot() -> Dictionary:
	return active_states.duplicate(true)


func block() -> void:
	_block_count += 1


func unblock() -> void:
	_block_count = maxi(0, _block_count - 1)


func write_to_save(save: PlayerSaveData) -> void:
	save.active_states = active_states.duplicate(true)


func restore_from_save(save: PlayerSaveData) -> void:
	active_states = save.active_states.duplicate(true) if save != null else {}
	_block_count = 1 if ("evolving" in active_states or "dying" in active_states) else 0


func show(emotion_name: String) -> void:
	if is_blocked() or emotion_name.is_empty():
		return
	var save := _session.player_save()
	if emotion_name == "sick" and save and not save.enfermo:
		save.enfermo = true
		_queue_stat_changed.call()
	if emotion_name in active_states:
		return
	var rule := find_rule(emotion_name)
	var stat_value := 100.0
	if rule and not rule.stat_key.is_empty() and save:
		var raw = save.get(rule.stat_key)
		if raw != null:
			stat_value = float(raw)
	active_states[emotion_name] = EmotionStateEntry.make(_session.total_hours(), stat_value)


func clear(emotion_name: String) -> void:
	active_states.erase(emotion_name)


## Las transiciones de vida son excluyentes: mientras una está activa no deben
## sobrevivir emociones de juego ni quedar el contador de bloqueo desbalanceado.
## StatsLifeStage usa esta API en vez de editar el diccionario serializado.
func transition_active() -> bool:
	return has_state("evolving") or has_state("dying")


func begin_reincarnation(cause: String) -> void:
	active_states.clear()
	active_states["dying"] = {
		"hour": _session.total_hours(), "stat_value": 100.0, "cause": cause,
	}
	block()


func begin_evolution(target_youn_path: String) -> void:
	active_states.clear()
	active_states["evolving"] = {
		"hour": _session.total_hours(), "stat_value": 100.0,
		"target_youn_path": target_youn_path,
	}
	block()


func transition_entry(name: String) -> Dictionary:
	return state_entry(name)


func finish_transition(name: String, clear_all: bool = false) -> void:
	if clear_all:
		active_states.clear()
	else:
		clear(name)
	unblock()


func check_expirations() -> void:
	var total_h := _session.total_hours()
	for emotion_name in active_states.keys():
		var rule := find_rule(emotion_name)
		if rule == null or rule.max_duration_hours <= 0.0:
			continue
		var since_hour := EmotionStateEntry.hour_of(active_states[emotion_name])
		if total_h - since_hour < rule.max_duration_hours:
			continue
		if emotion_name == "bathroom":
			_apply_bathroom_accident.call()
			continue
		_apply_expire_penalty.call(rule)
		clear(emotion_name)


func evaluate_rules() -> void:
	var ps := _session.player_save()
	if ps == null or _rules.is_empty() or is_blocked():
		return
	var ctx := {"save": ps, "youn_data": _session.youn_data(), "active": active_states.keys(), "random": _random}
	for emotion_name in EmotionEngine.evaluate(_rules, ctx):
		show(emotion_name)
	for emotion_name in active_states.keys():
		if emotion_name == "sick":
			continue
		var rule := find_rule(emotion_name)
		if rule == null:
			continue
		if rule is EmotionRuleTimeWindow:
			if ctx["youn_data"] != null and rule.evaluate(ctx) <= 0.0:
				clear(emotion_name)
			continue
		if rule.stat_key.is_empty():
			continue
		var current_val = ps.get(rule.stat_key)
		if current_val != null and rule.improved_since(EmotionStateEntry.stat_value_of(active_states[emotion_name]), float(current_val)) and _random.randf() >= rule.evaluate(ctx):
			clear(emotion_name)


func sync_sick() -> void:
	var ps := _session.player_save()
	if ps != null and ps.enfermo and "sick" not in active_states:
		show("sick")


func on_wake_up(sleep_duration_hours: float) -> void:
	clear("tired")
	clear("sleep")
	var bathroom_rule := find_rule("bathroom")
	if "bathroom" in active_states and bathroom_rule:
		var elapsed := _session.total_hours() - EmotionStateEntry.hour_of(active_states["bathroom"])
		if elapsed >= bathroom_rule.max_duration_hours * 0.5:
			_apply_bathroom_accident.call()
		else:
			EmotionStateEntry.set_hour(active_states["bathroom"], EmotionStateEntry.hour_of(active_states["bathroom"]) + sleep_duration_hours)
	for emotion_name in active_states.keys():
		if emotion_name != "bathroom":
			EmotionStateEntry.set_hour(active_states[emotion_name], EmotionStateEntry.hour_of(active_states[emotion_name]) + sleep_duration_hours)


func find_rule(emotion_name: String) -> EmotionRule:
	for rule in _rules:
		if rule.emotion_name == emotion_name:
			return rule
	return null


func _load_rules() -> Array[EmotionRule]:
	var result: Array[EmotionRule] = []
	for rule in ResourceCatalogLoader.resources(RULES_DIR, EmotionRule):
		result.append(rule as EmotionRule)
	return result
